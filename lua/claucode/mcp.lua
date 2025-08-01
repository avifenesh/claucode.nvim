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
  
  vim.notify("Building MCP server in: " .. mcp_dir, vim.log.levels.INFO)
  
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
  
  vim.notify("MCP server built successfully!", vim.log.levels.INFO)
  return true
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

-- Generate MCP config for Claude Code CLI
local function generate_mcp_config()
  local mcp_server = get_mcp_server_path()
  if not mcp_server then
    return nil
  end
  
  return {
    mcpServers = {
      ["claucode-nvim"] = {
        command = "node",
        args = {mcp_server},
        env = {
          NVIM = vim.v.servername
        },
        description = "Neovim diff preview for file operations"
      }
    }
  }
end

-- Write MCP config to a temporary file
local function write_mcp_config()
  local config = generate_mcp_config()
  if not config then
    vim.notify("MCP server not found. Please build it first.", vim.log.levels.ERROR)
    return nil
  end
  
  local config_file = vim.fn.tempname() .. ".json"
  local file = io.open(config_file, "w")
  if file then
    file:write(vim.fn.json_encode(config))
    file:close()
    return config_file
  end
  
  return nil
end

-- Show diff preview
function M.show_diff(hash, filepath)
  -- Make HTTP request to MCP server to get diff content
  local cmd = string.format(
    'curl -s -X POST -H "Content-Type: application/json" ' ..
    '-d \'{"method":"call_tool","params":{"name":"get_diff","arguments":{"hash":"%s"}}}\' ' ..
    'http://localhost:8080/mcp',
    hash
  )
  
  -- For now, we'll use a simpler approach with job control
  vim.fn.jobstart({"claude", "mcp", "call", "claucode-nvim", "get_diff", "--args", vim.fn.json_encode({hash = hash})}, {
    on_stdout = function(_, data)
      local content = table.concat(data, "\n")
      local ok, diff_data = pcall(vim.fn.json_decode, content)
      
      if ok and diff_data then
        vim.schedule(function()
          M.show_diff_window(hash, filepath, diff_data.original, diff_data.modified)
        end)
      end
    end
  })
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
    "# Press 'a' to accept, 'r' to reject",
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
    -- Send response to MCP server
    vim.fn.jobstart({
      "claude", "mcp", "call", "claucode-nvim", "respond_to_diff",
      "--args", vim.fn.json_encode({hash = hash, approved = approved})
    })
    
    -- Clean up
    vim.api.nvim_win_close(win, true)
    pending_diffs[hash] = nil
  end
  
  -- Set up keymaps
  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "a", function() respond(true) end, opts)
  vim.keymap.set("n", "r", function() respond(false) end, opts)
  vim.keymap.set("n", "q", function() respond(false) end, opts)
  vim.keymap.set("n", "<Esc>", function() respond(false) end, opts)
  
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

-- Get MCP config file path
function M.get_mcp_config_file()
  return M.mcp_config_file
end

-- Setup MCP integration
function M.setup(config)
  -- Debug: Show plugin root
  local root = get_plugin_root()
  vim.notify("MCP setup - Plugin root: " .. root, vim.log.levels.DEBUG)
  
  -- Check if MCP server is available
  local mcp_server = get_mcp_server_path()
  if not mcp_server and config.mcp and config.mcp.auto_build then
    vim.notify("MCP server not found, attempting auto-build...", vim.log.levels.INFO)
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
  
  -- Generate and write MCP config
  M.mcp_config_file = write_mcp_config()
  if not M.mcp_config_file then
    return
  end
  
  -- Configure Claude Code CLI to use our MCP server
  vim.notify("Claucode MCP server configured at: " .. M.mcp_config_file, vim.log.levels.INFO)
  
  -- Set environment variable for Claude commands
  vim.env.CLAUDE_MCP_CONFIG = M.mcp_config_file
end

return M