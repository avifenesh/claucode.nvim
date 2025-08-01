-- Debug the Claude command execution
local bridge = require("claucode.bridge")
local config = require("claucode").get_config()

vim.notify("=== Debugging Claude Command ===", vim.log.levels.INFO)
vim.notify("Command path: " .. config.command, vim.log.levels.INFO)
vim.notify("Command exists: " .. vim.fn.executable(config.command), vim.log.levels.INFO)

-- Test direct system call
local test_output = vim.fn.system(config.command .. " --version")
vim.notify("Version test: " .. test_output:sub(1, 100), vim.log.levels.INFO)

-- Now test with our bridge
local original_parse = bridge.parse_streaming_json
if not original_parse then
  -- Get access to the parse function
  local parse_streaming_json = function(line)
    vim.notify("[RAW LINE]: " .. vim.inspect(line), vim.log.levels.INFO)
  end
  
  -- Monkey patch to see raw output
  local old_stdout_handler
  
  bridge.send_to_claude_debug = function(prompt)
    local uv = vim.loop
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false) 
    local stdin = uv.new_pipe(false)
    
    local process = uv.spawn(config.command, {
      args = {"-p", "test"},
      stdio = {stdin, stdout, stderr},
      cwd = vim.fn.getcwd(),
    }, function(code, signal)
      vim.notify("Process exited: " .. tostring(code), vim.log.levels.INFO)
    end)
    
    if not process then
      vim.notify("Failed to spawn process!", vim.log.levels.ERROR)
      return
    end
    
    stdout:read_start(function(err, data)
      if err then
        vim.notify("stdout error: " .. err, vim.log.levels.ERROR)
      elseif data then
        vim.notify("[STDOUT]: " .. data:sub(1, 200), vim.log.levels.INFO)
      end
    end)
    
    stderr:read_start(function(err, data)
      if err then
        vim.notify("stderr error: " .. err, vim.log.levels.ERROR)
      elseif data then
        vim.notify("[STDERR]: " .. data:sub(1, 200), vim.log.levels.INFO)
      end
    end)
    
    stdin:close()
  end
end

-- Run the debug version
vim.defer_fn(function()
  if bridge.send_to_claude_debug then
    bridge.send_to_claude_debug("test")
  else
    -- Use normal send
    bridge.send_to_claude("test", {})
  end
end, 500)