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
  
  vim.notify("Building MCP server in: " .. mcp_dir, vim.log.levels.DEBUG)
  
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
  
  vim.notify("MCP server built successfully!", vim.log.levels.DEBUG)
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
  
  vim.notify("Building MCP server in: " .. mcp_dir, vim.log.levels.DEBUG)
  
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
            vim.notify("MCP server built successfully!", vim.log.levels.DEBUG)
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
  
  -- Create diff buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
  
  -- Generate diff lines
  local diff_lines = {
    "# Claucode MCP Diff Preview",
    "# Press 'a' to accept, 'r' to reject, 'q' or <Esc> to cancel",
    "# Instance: " .. vim.fn.getpid(),
    "",
    "--- " .. filepath,
    "+++ " .. filepath .. " (proposed)",
    ""
  }
  
  -- Simple line-by-line diff
  local original_lines = vim.split(original, "\n", { plain = true })
  local modified_lines = vim.split(modified, "\n", { plain = true })
  
  local max_lines = math.max(#original_lines, #modified_lines)
  for i = 1, max_lines do
    local orig = original_lines[i] or ""
    local mod = modified_lines[i] or ""
    
    if orig ~= mod then
      if orig ~= "" then
        table.insert(diff_lines, "-" .. orig)
      end
      if mod ~= "" then
        table.insert(diff_lines, "+" .. mod)
      end
    else
      if orig ~= "" then
        table.insert(diff_lines, " " .. orig)
      end
    end
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  
  -- Calculate window size
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Claucode Diff: " .. vim.fn.fnamemodify(filepath, ":t") .. " ",
    title_pos = "center",
  })
  
  -- Response function
  local function respond(approved)
    -- Show feedback
    vim.notify(approved and "Accepting changes..." or "Rejecting changes...", vim.log.levels.DEBUG)
    
    -- Write response to file
    local dir = get_communication_dir()
    local response_file = dir .. "/" .. hash .. ".response.json"
    local response_data = vim.fn.json_encode({
      hash = hash,
      approved = approved,
      timestamp = os.time()
    })
    
    vim.fn.writefile({response_data}, response_file)
    
    -- Clean up
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    pending_diffs[hash] = nil
    
    -- Log the response
    vim.notify("Diff " .. (approved and "accepted" or "rejected") .. " for " .. filepath, vim.log.levels.DEBUG)
  end
  
  -- Set up keymaps
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "a", function() respond(true) end, opts)
  vim.keymap.set("n", "r", function() respond(false) end, opts)
  vim.keymap.set("n", "q", function() respond(false) end, opts)
  vim.keymap.set("n", "<Esc>", function() respond(false) end, opts)
  
  -- Add navigation keymaps
  vim.keymap.set("n", "j", "j", opts)
  vim.keymap.set("n", "k", "k", opts)
  vim.keymap.set("n", "h", "h", opts)
  vim.keymap.set("n", "l", "l", opts)
  vim.keymap.set("n", "<C-d>", "<C-d>", opts)
  vim.keymap.set("n", "<C-u>", "<C-u>", opts)
  vim.keymap.set("n", "G", "G", opts)
  vim.keymap.set("n", "gg", "gg", opts)
  
  -- Add help keymap
  vim.keymap.set("n", "?", function()
    vim.notify("Diff Preview Keys: a=accept, r=reject, q/<Esc>=cancel, j/k=scroll", vim.log.levels.INFO)
  end, opts)
  
  -- Remove the WinLeave autocmd as it prevents scrolling and closing
  
  -- Apply syntax highlighting
  vim.cmd([[
    syntax match DiffAdded "^+.*"
    syntax match DiffRemoved "^-.*"
    syntax match DiffFile "^---.*\|^+++.*"
    syntax match DiffHeader "^#.*"
    
    highlight link DiffAdded DiffAdd
    highlight link DiffRemoved DiffDelete
    highlight link DiffFile Special
    highlight link DiffHeader Comment
  ]])
end

-- Setup MCP integration
function M.setup(config)
  -- Debug: Show plugin root
  local root = get_plugin_root()
  -- vim.notify("MCP setup - Plugin root: " .. root, vim.log.levels.DEBUG)
  
  -- Check if MCP server is available
  local mcp_server = get_mcp_server_path()
  if not mcp_server and config.mcp and config.mcp.auto_build then
    vim.notify("MCP server not found, attempting auto-build...", vim.log.levels.DEBUG)
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
    vim.notify("Claucode diff watcher started", vim.log.levels.DEBUG)
  end
end

-- Cleanup function
function M.cleanup()
  M.stop_diff_watcher()
end

return M