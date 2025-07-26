local M = {}

local uv = vim.loop
local current_process = nil
local output_buffer = ""
local callbacks = {}

local function escape_prompt(prompt)
  -- Escape special characters for shell
  return prompt:gsub('"', '\\"'):gsub('\n', '\\n')
end

local function parse_streaming_json(line)
  if line == "" then return end
  
  -- Try to parse each line as JSON
  local ok, result = pcall(vim.json.decode, line)
  if not ok then return end
  
  -- Handle different event types
  if result.type == "message" and result.subtype == "start" then
    if callbacks.on_start then
      callbacks.on_start()
    end
  elseif result.type == "content" and result.subtype == "text" then
    -- Real-time content streaming
    if result.text and callbacks.on_stream then
      callbacks.on_stream(result.text)
    end
  elseif result.type == "tool_use" then
    -- Tool usage notification
    if callbacks.on_tool_use then
      callbacks.on_tool_use(result)
    end
    -- Check for file modifications
    if result.name == "Edit" or result.name == "Write" then
      local input = result.input
      if input and input.file_path and callbacks.on_file_change then
        callbacks.on_file_change(input.file_path)
      end
    end
  elseif result.type == "result" then
    -- Final result
    if callbacks.on_result then
      callbacks.on_result(result)
    end
  end
end

function M.send_to_claude(prompt, opts)
  opts = opts or {}
  local config = require("claucode").get_config()
  
  -- Build command arguments
  local args = {}
  
  -- Use print mode with streaming JSON output for real-time feedback
  table.insert(args, "-p")
  table.insert(args, "--output-format")
  table.insert(args, "stream-json")
  
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
      end
      -- Process any remaining data in buffer
      if json_buffer ~= "" then
        parse_streaming_json(json_buffer)
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
  
  -- Read stdout line by line for streaming
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Error reading Claude output: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data then
      json_buffer = json_buffer .. data
      -- Process complete lines
      local lines = vim.split(json_buffer, "\n", { plain = true })
      
      -- Keep incomplete line in buffer
      if not json_buffer:match("\n$") and #lines > 1 then
        json_buffer = lines[#lines]
        table.remove(lines, #lines)
      else
        json_buffer = ""
      end
      
      -- Process each complete line
      for _, line in ipairs(lines) do
        if line ~= "" then
          vim.schedule(function()
            parse_streaming_json(line)
          end)
        end
      end
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