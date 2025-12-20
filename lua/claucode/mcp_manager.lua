local M = {}

-- Get the MCP server name for this session
local function get_mcp_server_name()
  local claucode = require("claucode")
  return claucode.get_mcp_server_name()
end

-- Get the claude command path
local function get_claude_command()
  local config = require("claucode").get_config()
  return config.command or "claude"
end

-- Check if our MCP server is already added to Claude (async)
local function is_mcp_server_added_async(callback)
  local claude_cmd = get_claude_command()
  local server_name = get_mcp_server_name()
  local output = ""
  
  vim.fn.jobstart({claude_cmd, "mcp", "list"}, {
    on_stdout = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback(false)
      else
        -- Look for our server name in the output
        callback(output:match(vim.pesc(server_name)) ~= nil)
      end
    end
  })
end

-- Add our MCP server to Claude configuration (async)
function M.add_mcp_server(callback)
  local notify = require("claucode.notify")
  
  -- Check if already added
  is_mcp_server_added_async(function(is_added)
    if is_added then
      -- MCP server already configured - silent
      if callback then callback(true) end
      return
    end
    
    -- Continue with the rest of the function
    M._continue_add_mcp_server(callback)
  end)
end

-- Internal function to continue adding MCP server
function M._continue_add_mcp_server(callback)
  local notify = require("claucode.notify")
  
  -- Get the MCP server path
  local source_path = debug.getinfo(1, "S").source:match("@(.*)")
  local current_file_dir = vim.fn.fnamemodify(source_path, ":h")
  local plugin_root = vim.fn.fnamemodify(current_file_dir, ":h")
  
  -- Try multiple possible paths
  local possible_paths = {
    plugin_root .. "/mcp-server/build/index.js",
    vim.fn.stdpath("data") .. "/lazy/claucode.nvim/mcp-server/build/index.js",
    vim.fn.expand("~/.local/share/nvim/lazy/claucode.nvim/mcp-server/build/index.js")
  }
  
  local mcp_server = nil
  for _, path in ipairs(possible_paths) do
    if vim.fn.filereadable(path) == 1 then
      mcp_server = path
      break
    end
  end
  
  if not mcp_server then
    -- Log all attempted paths for debugging
    notify.error("MCP server not found. Attempted paths:")
    for _, path in ipairs(possible_paths) do
      notify.error("  - " .. path)
    end
    mcp_server = possible_paths[1] -- Use first path as fallback
  end
  
  -- Check if MCP server is built
  if vim.fn.filereadable(mcp_server) == 0 then
    -- Try to build it
    local mcp = require("claucode.mcp")
    if mcp.build_async then
      notify.mcp_setup("MCP server not found, attempting to build...", { force = true })
      mcp.build_async(require("claucode").get_config(), function(success)
        if success and vim.fn.filereadable(mcp_server) == 1 then
          -- Continue with adding the server
          M._do_add_mcp_server(mcp_server, callback)
        else
          notify.error("MCP server build failed. Path: " .. mcp_server)
          if callback then callback(false) end
        end
      end)
      return
    else
      notify.error("MCP server not built. Please build it first.")
      if callback then callback(false) end
      return
    end
  else
    notify.mcp_setup("Found MCP server at: " .. mcp_server, { force = false })
  end
  
  -- Continue with adding the server
  M._do_add_mcp_server(mcp_server, callback)
end

-- Actually add the MCP server
function M._do_add_mcp_server(mcp_server, callback)
  local notify = require("claucode.notify")
  local server_name = get_mcp_server_name()
  local session_id = require("claucode").get_session_id()
  
  -- Add the MCP server using claude mcp add command
  local claude_cmd = get_claude_command()
  
  -- Adding MCP server to Claude configuration
  -- Pass session ID via environment variable to the MCP server
  
  local output = ""
  vim.fn.jobstart({claude_cmd, "mcp", "add", "--scope", "user", server_name, "node", mcp_server, session_id}, {
    on_stdout = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_stderr = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        notify.error("Failed to add MCP server: " .. output)
        
        -- Check if it's because claude doesn't support mcp subcommand
        if output:match("Unknown command") or output:match("command not found") then
          notify.error("Your Claude CLI version doesn't support 'mcp' command.")
          notify.error("Please update Claude Code CLI to the latest version.")
        end
        
        if callback then callback(false) end
      else
        -- Removed startup notification to reduce noise
        if callback then callback(true) end
      end
    end
  })
end

-- Remove our MCP server from Claude configuration
function M.remove_mcp_server()
  local notify = require("claucode.notify")
  local server_name = get_mcp_server_name()
  local claude_cmd = get_claude_command()
  local cmd = claude_cmd .. " mcp remove " .. server_name
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    notify.error("Failed to remove MCP server: " .. output)
    return false
  end
  
  notify.info("Claucode MCP server removed from Claude")
  return true
end

-- Setup function
function M.setup(config)
  -- Only setup if MCP is enabled and show_diff is true
  if config.mcp and config.mcp.enabled and config.bridge and config.bridge.show_diff then
    -- Delay to ensure everything is loaded
    vim.defer_fn(function()
      M.add_mcp_server(function(success)
        if success then
          -- MCP server setup complete
        end
      end)
    end, 1000)
  end
end

return M