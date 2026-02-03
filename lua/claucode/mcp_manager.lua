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
  -- Go up two levels: lua/claucode -> lua -> plugin_root
  local plugin_root = vim.fn.fnamemodify(current_file_dir, ":h:h")

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
    local notify = require("claucode.notify")
    notify.error("MCP server not found. Attempted paths:")
    for _, path in ipairs(possible_paths) do
      notify.error("  - " .. path)
    end
    mcp_server = possible_paths[1] -- Use first path as fallback
  end
  
  if vim.fn.filereadable(mcp_server) == 0 then
    local mcp = require("claucode.mcp")
    local notify = require("claucode.notify")
    if mcp.build_async then
      notify.mcp_setup("MCP server not found, attempting to build...", { force = true })
      mcp.build_async(require("claucode").get_config(), function(success)
        if success and vim.fn.filereadable(mcp_server) == 1 then
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
        local notify = require("claucode.notify")
        notify.error("Failed to add MCP server: " .. output)

        if output:match("Unknown command") or output:match("command not found") then
          notify.error("Your Claude CLI version doesn't support 'mcp' command.")
          notify.error("Please update Claude Code CLI to the latest version.")
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
  local notify = require("claucode.notify")
  local server_name = session.get_mcp_server_name()
  local project_dir = session.get_project_dir()

  -- Use array form to prevent shell injection
  -- vim.fn.system doesn't support cwd parameter, so we temporarily change directory
  local output
  do
    local prev_cwd = vim.fn.getcwd()
    vim.api.nvim_set_current_dir(project_dir)
    output = vim.fn.system({claude_cmd, "mcp", "remove", server_name})
    vim.api.nvim_set_current_dir(prev_cwd)
  end
  if vim.v.shell_error ~= 0 then
    notify.error("Failed to remove MCP server: " .. (output or ""))
    return false
  end

  notify.mcp_setup("Claucode MCP server removed from Claude")
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