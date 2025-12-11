local M = {}

local function get_claude_command()
  local config = require("claucode").get_config()
  return config.command or "claude"
end

local function is_mcp_server_added_async(callback)
  local session = require("claucode.session")
  local server_name = session.get_mcp_server_name()
  local project_dir = session.get_project_dir()

  local mcp_json_path = project_dir .. "/.mcp.json"
  if vim.fn.filereadable(mcp_json_path) == 1 then
    local content = vim.fn.readfile(mcp_json_path)
    local json_str = table.concat(content, "\n")
    local ok, config = pcall(vim.fn.json_decode, json_str)
    if ok and config and config.mcpServers and config.mcpServers[server_name] then
      callback(true)
      return
    end
  end

  local claude_cmd = get_claude_command()
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
        local pattern = server_name:gsub("%-", "%%-")
        callback(output:match(pattern) ~= nil)
      end
    end
  })
end

function M.add_mcp_server(callback)
  -- Check if already added
  is_mcp_server_added_async(function(is_added)
    if is_added then
      if callback then callback(true) end
      return
    end
    
    M._continue_add_mcp_server(callback)
  end)
end

function M._continue_add_mcp_server(callback)
  local source_path = debug.getinfo(1, "S").source:match("@(.*)")
  local current_file_dir = vim.fn.fnamemodify(source_path, ":h")
  local plugin_root = vim.fn.fnamemodify(current_file_dir, ":h")
  
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
    vim.notify("MCP server not found. Attempted paths:", vim.log.levels.ERROR)
    for _, path in ipairs(possible_paths) do
      vim.notify("  - " .. path, vim.log.levels.ERROR)
    end
    mcp_server = possible_paths[1] -- Use first path as fallback
  end
  
  if vim.fn.filereadable(mcp_server) == 0 then
    local mcp = require("claucode.mcp")
    if mcp.build_async then
      vim.notify("MCP server not found, attempting to build...", vim.log.levels.INFO)
      mcp.build_async(require("claucode").get_config(), function(success)
        if success and vim.fn.filereadable(mcp_server) == 1 then
          M._do_add_mcp_server(mcp_server, callback)
        else
          vim.notify("MCP server build failed. Path: " .. mcp_server, vim.log.levels.ERROR)
          if callback then callback(false) end
        end
      end)
      return
    else
      vim.notify("MCP server not built. Please build it first.", vim.log.levels.ERROR)
      if callback then callback(false) end
      return
    end
  else
    vim.notify("Found MCP server at: " .. mcp_server, vim.log.levels.INFO)
  end
  
  M._do_add_mcp_server(mcp_server, callback)
end

function M._do_add_mcp_server(mcp_server, callback)
  local claude_cmd = get_claude_command()
  local session = require("claucode.session")
  local server_name = session.get_mcp_server_name()
  local comm_dir = session.get_communication_dir()
  local project_dir = session.get_project_dir()

  local output = ""
  vim.fn.jobstart({
    claude_cmd, "mcp", "add",
    "--scope", "project",
    server_name,
    "-e", "CLAUCODE_SESSION_ID=" .. server_name,
    "-e", "CLAUCODE_COMM_DIR=" .. comm_dir,
    "--",
    "node", mcp_server
  }, {
    cwd = project_dir,
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
        vim.notify("Failed to add MCP server: " .. output, vim.log.levels.ERROR)

        if output:match("Unknown command") or output:match("command not found") then
          vim.notify("Your Claude CLI version doesn't support 'mcp' command.", vim.log.levels.ERROR)
          vim.notify("Please update Claude Code CLI to the latest version.", vim.log.levels.ERROR)
        end

        if callback then callback(false) end
      else
        if callback then callback(true) end
      end
    end
  })
end

function M.remove_mcp_server()
  local claude_cmd = get_claude_command()
  local session = require("claucode.session")
  local server_name = session.get_mcp_server_name()
  local project_dir = session.get_project_dir()

  local cmd = string.format("cd '%s' && %s mcp remove %s", project_dir, claude_cmd, server_name)
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to remove MCP server: " .. output, vim.log.levels.ERROR)
    return false
  end

  vim.notify("Claucode MCP server removed from Claude", vim.log.levels.INFO)
  return true
end

function M.setup(config)
  if config.mcp and config.mcp.enabled and config.bridge and config.bridge.show_diff then
    vim.defer_fn(function()
      M.add_mcp_server(function(success)
      end)
    end, 1000)
  end
end

return M