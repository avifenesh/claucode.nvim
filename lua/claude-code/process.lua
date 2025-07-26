local M = {}
local uv = vim.loop

local process = nil
local config = {}

function M.init(opts)
  config = opts
end

function M.spawn(args, callbacks)
  if process and process.handle then
    vim.notify("Claude Code process already running", vim.log.levels.WARN)
    return process
  end
  
  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()
  
  local cmd_args = vim.list_extend({
    '--output-format', 'json',
    '--model', config.model or 'sonnet'
  }, args or {})
  
  local handle
  handle = uv.spawn(config.command or 'claude', {
    args = cmd_args,
    stdio = {stdin, stdout, stderr}
  }, function(code, signal)
    if callbacks.on_exit then
      vim.schedule(function()
        callbacks.on_exit(code, signal)
      end)
    end
    M.cleanup()
  end)
  
  if not handle then
    vim.notify("Failed to start Claude Code process", vim.log.levels.ERROR)
    return nil
  end
  
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Claude Code stdout error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data and callbacks.on_stdout then
      vim.schedule(function()
        callbacks.on_stdout(data)
      end)
    end
  end)
  
  stderr:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Claude Code stderr error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data and callbacks.on_stderr then
      vim.schedule(function()
        callbacks.on_stderr(data)
      end)
    end
  end)
  
  process = {
    handle = handle,
    stdin = stdin,
    stdout = stdout,
    stderr = stderr,
    pid = handle:get_pid()
  }
  
  return process
end

function M.send(data)
  if not process or not process.stdin then
    vim.notify("Claude Code process not running", vim.log.levels.ERROR)
    return false
  end
  
  local json_data = vim.fn.json_encode(data)
  process.stdin:write(json_data .. '\n')
  return true
end

function M.stop()
  if process and process.handle then
    process.handle:kill('sigterm')
    M.cleanup()
  end
end

function M.cleanup()
  if process then
    if process.stdin then process.stdin:close() end
    if process.stdout then process.stdout:close() end
    if process.stderr then process.stderr:close() end
    if process.handle then process.handle:close() end
    process = nil
  end
end

function M.is_running()
  return process ~= nil and process.handle ~= nil
end

return M