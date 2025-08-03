local M = {}

local uv = vim.loop
local mcp_process = nil
local pending_diffs = {}

-- Get the plugin root directory
local function get_plugin_root()
  -- Try to find the plugin root by looking for the lua/claucode directory
  local source_path = debug.getinfo(1, "S").source:match("@(.*)")
  local current_file_dir = vim.fn.fnamemodify(source_path, ":h")
  
  -- We're in lua/claucode/, so go up two levels
  local plugin_root = vim.fn.fnamemodify(current_file_dir, ":h:h")
  
  -- Verify it's the correct directory by checking for key files
  if vim.fn.filereadable(plugin_root .. "/README.md") == 1 then
    return plugin_root
  end
  
  -- Fallback: check common lazy.nvim installation paths
  local lazy_path = vim.fn.stdpath("data") .. "/lazy/claucode.nvim"
  if vim.fn.isdirectory(lazy_path) == 1 then
    return lazy_path
  end
  
  -- Last resort: return the computed path
  return plugin_root
end

-- Build the MCP server
local function build_mcp_server()
  local root = get_plugin_root()
  local mcp_dir = root .. "/mcp-server"
  
  -- Check if source files exist
  if vim.fn.isdirectory(mcp_dir) == 0 then
    vim.notify("MCP server source not found at: " .. mcp_dir, vim.log.levels.ERROR)
    return false
  end
  
  -- Building MCP server
  
  -- Check if npm is available
  if vim.fn.executable("npm") == 0 then
    vim.notify("npm not found. Please install Node.js and npm to use diff preview.", vim.log.levels.ERROR)
    return false
  end
  
  -- Run npm install
  local install_cmd = string.format("cd '%s' && npm install", mcp_dir)
  local install_result = vim.fn.system(install_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to install MCP dependencies: " .. install_result, vim.log.levels.ERROR)
    return false
  end
  
  -- Run npm build
  local build_cmd = string.format("cd '%s' && npm run build", mcp_dir)
  local build_result = vim.fn.system(build_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to build MCP server: " .. build_result, vim.log.levels.ERROR)
    return false
  end
  
  -- MCP server built successfully
  return true
end

-- Build the MCP server (async)
function M.build_async(config, callback)
  local root = get_plugin_root()
  local mcp_dir = root .. "/mcp-server"
  
  -- Check if source files exist
  if vim.fn.isdirectory(mcp_dir) == 0 then
    vim.notify("MCP server source not found at: " .. mcp_dir, vim.log.levels.ERROR)
    if callback then callback(false) end
    return
  end
  
  -- Building MCP server
  
  -- Check if npm is available
  if vim.fn.executable("npm") == 0 then
    vim.notify("npm not found. Please install Node.js and npm to use diff preview.", vim.log.levels.ERROR)
    if callback then callback(false) end
    return
  end
  
  -- Run npm install first
  vim.fn.jobstart({"sh", "-c", "cd '" .. mcp_dir .. "' && npm install"}, {
    on_exit = function(_, install_code)
      if install_code ~= 0 then
        vim.notify("Failed to install MCP dependencies", vim.log.levels.ERROR)
        if callback then callback(false) end
        return
      end
      
      -- Run npm build after install succeeds
      vim.fn.jobstart({"sh", "-c", "cd '" .. mcp_dir .. "' && npm run build"}, {
        on_exit = function(_, build_code)
          if build_code ~= 0 then
            vim.notify("Failed to build MCP server", vim.log.levels.ERROR)
            if callback then callback(false) end
          else
            -- MCP server built successfully
            if callback then callback(true) end
          end
        end
      })
    end
  })
end

-- Get the MCP server path
local function get_mcp_server_path()
  local root = get_plugin_root()
  
  -- Check the correct build output location
  local plugin_path = root .. "/mcp-server/build/index.js"
  if vim.fn.filereadable(plugin_path) == 1 then
    return plugin_path
  end
  
  -- Check global installation
  if vim.fn.executable("claucode-mcp") == 1 then
    return "claucode-mcp"
  end
  
  return nil
end


-- Get communication directory (must match MCP server)
local function get_communication_dir()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")
  return data_dir .. "/claucode/diffs"
end

-- Ensure communication directory exists
local function ensure_communication_dir()
  local dir = get_communication_dir()
  vim.fn.mkdir(dir, "p")
  return dir
end

-- Start watching for diff requests
function M.start_diff_watcher()
  if M.diff_watcher_timer then
    return -- Already watching
  end
  
  local dir = ensure_communication_dir()
  
  -- Poll for request files
  M.diff_watcher_timer = vim.loop.new_timer()
  M.diff_watcher_timer:start(0, 500, vim.schedule_wrap(function()
    -- List all .request.json files
    local handle = vim.loop.fs_scandir(dir)
    if not handle then return end
    
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      
      if type == "file" and name:match("%.request%.json$") then
        local request_file = dir .. "/" .. name
        local content = vim.fn.readfile(request_file)
        if #content > 0 then
          local ok, request = pcall(vim.fn.json_decode, table.concat(content, "\n"))
          if ok and request then
            -- Delete request file immediately to prevent re-processing
            vim.fn.delete(request_file)
            -- Process the diff request
            vim.schedule(function()
              M.show_diff_window(request.hash, request.filepath, request.original, request.modified)
            end)
          end
        end
      end
    end
  end))
end

-- Stop diff watcher
function M.stop_diff_watcher()
  if M.diff_watcher_timer then
    M.diff_watcher_timer:close()
    M.diff_watcher_timer = nil
  end
end

-- Show diff in a floating window
function M.show_diff_window(hash, filepath, original, modified)
  -- Store for later response
  pending_diffs[hash] = {
    filepath = filepath,
    original = original,
    modified = modified
  }
  
  -- Create two buffers for side-by-side view
  local orig_buf = vim.api.nvim_create_buf(false, true)
  local mod_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  for _, buf in ipairs({orig_buf, mod_buf}) do
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
  end
  
  -- Set content
  local original_lines = vim.split(original, "\n", { plain = true })
  local modified_lines = vim.split(modified, "\n", { plain = true })
  
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, original_lines)
  vim.api.nvim_buf_set_lines(mod_buf, 0, -1, false, modified_lines)
  
  -- Make buffers read-only
  vim.api.nvim_buf_set_option(orig_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(mod_buf, "modifiable", false)
  
  -- Set filetype based on file extension
  local ft = vim.filetype.match({ filename = filepath }) or "text"
  vim.api.nvim_buf_set_option(orig_buf, "filetype", ft)
  vim.api.nvim_buf_set_option(mod_buf, "filetype", ft)
  
  -- Calculate window sizes
  local total_width = math.floor(vim.o.columns * 0.9)
  local total_height = math.floor(vim.o.lines * 0.8)
  local half_width = math.floor((total_width - 3) / 2) -- -3 for border between windows
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)
  
  -- Create left window (original)
  local left_win = vim.api.nvim_open_win(orig_buf, false, {
    relative = "editor",
    width = half_width,
    height = total_height - 4, -- Leave space for header
    row = row + 4,
    col = col,
    style = "minimal",
    border = "single",
  })
  
  -- Create right window (modified)
  local right_win = vim.api.nvim_open_win(mod_buf, true, {
    relative = "editor",
    width = half_width,
    height = total_height - 4,
    row = row + 4,
    col = col + half_width + 2,
    style = "minimal",
    border = "single",
  })
  
  -- Create header buffer for instructions
  local header_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(header_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(header_buf, "bufhidden", "wipe")
  
  local header_lines = {
    "Claucode Diff Preview: " .. vim.fn.fnamemodify(filepath, ":t"),
    "Press 'a' to accept, 'r' to reject, 'q' or <Esc> to cancel | Tab/<C-h>/<C-l> to switch windows",
    string.rep(" ", math.floor((half_width - 4) / 2)) .. "ORIGINAL" .. string.rep(" ", math.ceil((half_width - 4) / 2)) .. 
    " │ " .. 
    string.rep(" ", math.floor((half_width - 4) / 2)) .. "PROPOSED" .. string.rep(" ", math.ceil((half_width - 4) / 2))
  }
  
  vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, header_lines)
  vim.api.nvim_buf_set_option(header_buf, "modifiable", false)
  
  -- Create header window
  local header_win = vim.api.nvim_open_win(header_buf, false, {
    relative = "editor",
    width = total_width,
    height = 3,
    row = row,
    col = col,
    style = "minimal",
    border = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
    title = " Diff Preview ",
    title_pos = "center",
  })
  
  -- Set window options for all windows
  for _, win in ipairs({left_win, right_win, header_win}) do
    vim.api.nvim_win_set_option(win, "scrolloff", 0)
    vim.api.nvim_win_set_option(win, "sidescrolloff", 0)
    vim.api.nvim_win_set_option(win, "cursorline", false)
    vim.api.nvim_win_set_option(win, "wrap", false)
  end
  
  -- Enable diff mode for both windows
  vim.api.nvim_win_call(left_win, function()
    vim.cmd("diffthis")
  end)
  vim.api.nvim_win_call(right_win, function()
    vim.cmd("diffthis")
  end)
  
  -- Response function
  local function respond(approved)
    -- Processing diff decision silently
    
    -- Write response to file
    local dir = get_communication_dir()
    local response_file = dir .. "/" .. hash .. ".response.json"
    local response_data = vim.fn.json_encode({
      hash = hash,
      approved = approved,
      timestamp = os.time()
    })
    
    vim.fn.writefile({response_data}, response_file)
    
    -- Clean up all windows and buffers
    for _, win in ipairs({left_win, right_win, header_win}) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    for _, buf in ipairs({orig_buf, mod_buf, header_buf}) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    pending_diffs[hash] = nil
    
    -- Diff response processed
  end
  
  -- Set up keymaps for all buffers
  for _, buf in ipairs({orig_buf, mod_buf, header_buf}) do
    local opts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "a", function() respond(true) end, opts)
    vim.keymap.set("n", "r", function() respond(false) end, opts)
    vim.keymap.set("n", "q", function() respond(false) end, opts)
    vim.keymap.set("n", "<Esc>", function() respond(false) end, opts)
  end
  
  -- Add navigation between windows
  for _, buf in ipairs({orig_buf, mod_buf}) do
    local opts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "<Tab>", "<C-w>w", opts)
    vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
    vim.keymap.set("n", "<C-l>", "<C-w>l", opts)
  end
end

-- Setup MCP integration
function M.setup(config)
  local root = get_plugin_root()
  
  -- Check if MCP server is available
  local mcp_server = get_mcp_server_path()
  if not mcp_server and config.mcp and config.mcp.auto_build then
    -- Auto-building MCP server
    -- Try to build the MCP server
    if build_mcp_server() then
      -- Check again after building
      mcp_server = get_mcp_server_path()
    end
  end
  
  if not mcp_server then
    vim.notify("MCP server not available. Please run: cd " .. root .. "/mcp-server && npm install && npm run build", vim.log.levels.WARN)
    return
  end
  
  -- Start diff watcher if show_diff is enabled
  if config.bridge and config.bridge.show_diff then
    M.start_diff_watcher()
    -- Removed startup notification to reduce noise
  end
end

-- Cleanup function
function M.cleanup()
  M.stop_diff_watcher()
end

return M