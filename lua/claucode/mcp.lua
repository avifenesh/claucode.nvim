local M = {}

local uv = vim.loop
local mcp_process = nil
local pending_diffs = {}

-- Get the MCP server path
local function get_mcp_server_path()
  -- First check if it's installed in the plugin directory
  local plugin_path = vim.fn.expand(debug.getinfo(1, "S").source:match("@(.*/)").. "../../mcp-server/build/index.js")
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
  -- Check if MCP server is available
  local mcp_server = get_mcp_server_path()
  if not mcp_server then
    vim.notify("Claucode MCP server not found. Building it...", vim.log.levels.INFO)
    
    -- Try to build the MCP server
    local plugin_dir = vim.fn.expand(debug.getinfo(1, "S").source:match("@(.*/)").. "../../")
    local build_cmd = string.format("cd %s/mcp-server && npm install && npm run build", plugin_dir)
    
    vim.fn.jobstart({"sh", "-c", build_cmd}, {
      on_exit = function(_, code)
        if code == 0 then
          vim.notify("Claucode MCP server built successfully", vim.log.levels.INFO)
          M.setup(config) -- Retry setup
        else
          vim.notify("Failed to build MCP server. Please run: cd " .. plugin_dir .. "/mcp-server && npm install && npm run build", vim.log.levels.ERROR)
        end
      end
    })
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