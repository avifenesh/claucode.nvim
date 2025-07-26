local M = {}

local uv = vim.loop
local current_process = nil
local output_buffer = ""
local callbacks = {}

local function escape_prompt(prompt)
  -- Escape special characters for shell
  return prompt:gsub('"', '\\"'):gsub('\n', '\\n')
end

local function parse_claude_output(data, is_json)
  if is_json then
    -- Try to parse JSON response
    local ok, result = pcall(vim.json.decode, data)
    if ok and result.type == "result" then
      if callbacks.on_result then
        callbacks.on_result(result)
      end
      -- Extract the actual response text
      if result.result and callbacks.on_output then
        callbacks.on_output(result.result)
      end
    end
  else
    -- Plain text output
    output_buffer = output_buffer .. data
    
    -- Look for file modifications in the output
    local modifications = {}
    
    -- Pattern to match file paths that Claude might be working on
    local file_pattern = "File: ([^\n]+)"
    for file in output_buffer:gmatch(file_pattern) do
      table.insert(modifications, file)
    end
    
    -- Also look for "Writing to" patterns
    local write_pattern = "Writing to ([^\n]+)"
    for file in output_buffer:gmatch(write_pattern) do
      table.insert(modifications, file)
    end
    
    -- Trigger callbacks for any registered listeners
    if callbacks.on_output then
      callbacks.on_output(data)
    end
    
    if #modifications > 0 and callbacks.on_file_change then
      for _, file in ipairs(modifications) do
        callbacks.on_file_change(file)
      end
    end
  end
end

function M.send_to_claude(prompt, opts)
  opts = opts or {}
  local config = require("claucode").get_config()
  
  -- Build command arguments
  local args = {}
  
  -- Use print mode with JSON output for better parsing
  table.insert(args, "-p")
  table.insert(args, "--output-format")
  table.insert(args, "json")
  
  -- For simple prompts, add as argument
  if prompt and prompt ~= "" and not use_stdin then
    table.insert(args, prompt)
  end
  
  -- Reset output buffer
  output_buffer = ""
  
  -- Create pipes for process communication
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local stdin = uv.new_pipe(false)
  
  -- For complex prompts, we'll use stdin
  local use_stdin = #prompt > 1000 or prompt:match("\n")
  
  -- Check if command exists first
  if vim.fn.executable(config.command) == 0 and vim.fn.filereadable(config.command) == 0 then
    vim.notify("Claude Code CLI not found: '" .. config.command .. "'", vim.log.levels.ERROR)
    vim.notify("Please install it with: npm install -g @anthropic-ai/claude-code", vim.log.levels.ERROR)
    return false
  end
  
  -- Buffer for collecting JSON output and stderr
  local json_buffer = ""
  local stderr_buffer = ""
  
  current_process = uv.spawn(config.command, {
    args = args,
    stdio = {stdin, stdout, stderr},
    cwd = vim.fn.getcwd(),
  }, function(code, signal)
    -- Process exit callback
    vim.schedule(function()
      if code ~= 0 then
        vim.notify("Claude Code exited with code: " .. code, vim.log.levels.ERROR)
        if stderr_buffer ~= "" then
          vim.notify("Error details: " .. stderr_buffer, vim.log.levels.ERROR)
        end
      else
        -- Parse the complete JSON output
        parse_claude_output(json_buffer, true)
      end
      current_process = nil
      
      if callbacks.on_exit then
        callbacks.on_exit(code, signal)
      end
    end)
  end)
  
  if not current_process then
    vim.notify("Failed to start Claude Code CLI", vim.log.levels.ERROR)
    return false
  end
  
  -- Read stdout
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Error reading Claude output: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data then
      json_buffer = json_buffer .. data
      -- Try to parse complete JSON when process ends
    end
  end)
  
  -- Read stderr
  stderr:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Error reading Claude stderr: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data then
      stderr_buffer = stderr_buffer .. data
      vim.schedule(function()
        -- Only show stderr if it contains actual errors
        if data:match("error") or data:match("Error") or data:match("failed") then
          vim.notify("Claude error: " .. data, vim.log.levels.ERROR)
        end
      end)
    end
  end)
  
  -- Write prompt to stdin if needed
  if use_stdin and prompt then
    stdin:write(prompt, function(err)
      if err then
        vim.schedule(function()
          vim.notify("Error writing to stdin: " .. err, vim.log.levels.ERROR)
        end)
      end
      stdin:close()
    end)
  else
    stdin:close()
  end
  
  return true
end

function M.stop()
  if current_process then
    current_process:kill("sigterm")
    current_process = nil
  end
end

function M.is_running()
  return current_process ~= nil
end

function M.register_callback(event, callback)
  callbacks[event] = callback
end

function M.unregister_callback(event)
  callbacks[event] = nil
end

return M