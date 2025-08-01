-- Minimal test to isolate the issue
local uv = vim.loop
local config = require("claucode").get_config()

vim.notify("=== Minimal Claude Test ===", vim.log.levels.INFO)

-- Create pipes
local stdout = uv.new_pipe(false)
local stderr = uv.new_pipe(false)
local stdin = uv.new_pipe(false)

-- Simple spawn test
local handle = uv.spawn(config.command, {
  args = {"-p", "say hello"},
  stdio = {stdin, stdout, stderr},
}, function(code, signal)
  vim.schedule(function()
    vim.notify("Process ended: code=" .. tostring(code) .. " signal=" .. tostring(signal), vim.log.levels.INFO)
  end)
end)

if not handle then
  vim.notify("Failed to spawn claude!", vim.log.levels.ERROR)
  return
end

vim.notify("Process spawned successfully", vim.log.levels.INFO)

-- Read stdout
stdout:read_start(function(err, data)
  if err then
    vim.schedule(function()
      vim.notify("stdout error: " .. err, vim.log.levels.ERROR)
    end)
  elseif data then
    vim.schedule(function()
      vim.notify("stdout: " .. data:sub(1, 100), vim.log.levels.INFO)
    end)
  end
end)

-- Read stderr
stderr:read_start(function(err, data)
  if err then
    vim.schedule(function()
      vim.notify("stderr error: " .. err, vim.log.levels.ERROR)
    end)
  elseif data then
    vim.schedule(function()
      vim.notify("stderr: " .. data:sub(1, 100), vim.log.levels.INFO)
    end)
  end
end)

-- Close stdin
stdin:close()