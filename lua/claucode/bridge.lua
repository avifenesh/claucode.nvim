local M = {}

local uv = vim.loop
local current_process = nil
local current_stdin = nil
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
  if not ok then 
    -- Log parse errors for debugging
    vim.schedule(function()
      -- Check if it's just empty or whitespace
      if line:match("^%s*$") then
        return
      end
      vim.notify("Failed to parse Claude output: " .. line:sub(1, 100), vim.log.levels.DEBUG)
    end)
    return 
  end
  
  -- Debug logging - log all events to understand what's happening
  vim.schedule(function()
    if result.type then
      vim.notify("Claude event: " .. result.type .. (result.subtype and ("/" .. result.subtype) or ""), vim.log.levels.DEBUG)
      
      -- Log full event for debugging
      if result.type ~= "assistant" or vim.log.levels.DEBUG then
        vim.notify("Event details: " .. vim.inspect(result):sub(1, 500), vim.log.levels.DEBUG)
      end
    end
  end)
  
  -- Handle different event types
  if result.type == "system" and result.subtype == "init" then
    callbacks._start_triggered = true
    if callbacks.on_start then
      callbacks.on_start()
    end
  elseif result.type == "completion" then
    -- New format from Claude Code CLI
    if result.completion and callbacks.on_stream then
      callbacks.on_stream(result.completion)
    end
  elseif result.type == "text" then
    -- Handle simple text output
    if result.text and callbacks.on_stream then
      callbacks.on_stream(result.text)
    end
  elseif result.type == "content" then
    -- Handle content events
    if result.content and callbacks.on_stream then
      callbacks.on_stream(result.content)
    end
  elseif result.type == "assistant" then
    -- Assistant message with content
    if result.message and result.message.content then
      for _, content in ipairs(result.message.content) do
        if content.type == "text" and content.text and callbacks.on_stream then
          callbacks.on_stream(content.text)
        elseif content.type == "tool_use" then
          -- Log tool use for debugging
          vim.schedule(function()
            vim.notify("Tool use: " .. (content.name or "unknown"), vim.log.levels.DEBUG)
            if content.input then
              vim.notify("Tool input: " .. vim.inspect(content.input), vim.log.levels.DEBUG)
            end
          end)
          
          if callbacks.on_tool_use then
            callbacks.on_tool_use(content)
          end
          
          -- Track file changes for both standard and MCP tools
          if content.name == "Edit" or content.name == "Write" or 
             content.name == "nvim_edit_with_diff" or content.name == "nvim_write_with_diff" then
            local input = content.input
            if input and input.file_path and callbacks.on_file_change then
              callbacks.on_file_change(input.file_path)
            end
          end
        end
      end
    end
  elseif result.type == "permission_request" then
    -- Handle permission requests based on MCP configuration
    vim.schedule(function()
      vim.notify("Permission request for tool: " .. (result.tool_name or "unknown"), vim.log.levels.DEBUG)
    end)
    
    local config = require("claucode").get_config()
    -- Only auto-approve if MCP is NOT handling diffs
    if not (config.mcp and config.mcp.enabled and config.bridge and config.bridge.show_diff) then
      if current_process and current_stdin then
        current_stdin:write("y\n")
      end
    end
  elseif result.type == "tool_response" then
    -- Tool response - we could show this too if needed
    if callbacks.on_tool_response then
      callbacks.on_tool_response(result)
    end
  elseif result.type == "result" then
    -- Final result
    callbacks._result_triggered = true
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
  -- Remove verbose flag as it might cause issues
  -- table.insert(args, "--verbose")
  table.insert(args, "--output-format")
  table.insert(args, "stream-json")
  
  -- Check if user has configured MCP and wants diff preview
  if config.mcp and config.mcp.enabled and config.bridge and config.bridge.show_diff then
    -- Check if CLAUDE.md has diff instructions
    local claude_md = require("claucode.claude_md")
    if not claude_md.has_diff_instructions() then
      vim.notify("Adding diff instructions to CLAUDE.md...", vim.log.levels.DEBUG)
      claude_md.add_diff_instructions()
    end
    
    -- Note: We don't use --mcp-config anymore as it overrides user's MCP servers
    -- Instead, we use `claude mcp add` to add our server to their configuration
    vim.notify("Using Claucode MCP server for diff preview", vim.log.levels.DEBUG)
  end
  
  -- Only use acceptEdits if MCP is not handling diffs
  if not (config.mcp and config.mcp.enabled and config.bridge and config.bridge.show_diff) then
    table.insert(args, "--permission-mode")
    table.insert(args, "acceptEdits")
  end
  
  -- For complex prompts, we'll use stdin
  local use_stdin = #prompt > 1000 or prompt:match("\n")
  
  -- For simple prompts, add as argument
  if prompt and prompt ~= "" and not use_stdin then
    table.insert(args, prompt)
  end
  
  -- Debug: Log the full command
  vim.schedule(function()
    vim.notify("Claude command: " .. config.command .. " " .. table.concat(args, " "), vim.log.levels.DEBUG)
  end)
  
  -- Reset output buffer and callbacks state
  output_buffer = ""
  callbacks._result_triggered = false
  callbacks._start_triggered = false
  
  -- Create pipes for process communication
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local stdin = uv.new_pipe(false)
  
  -- Check if command exists first
  if vim.fn.executable(config.command) == 0 and vim.fn.filereadable(config.command) == 0 then
    vim.notify("Claude Code CLI not found: '" .. config.command .. "'", vim.log.levels.ERROR)
    vim.notify("Please install it with: npm install -g @anthropic-ai/claude-code", vim.log.levels.ERROR)
    return false
  end
  
  -- Log the full command being executed
  vim.notify("Executing Claude with args: " .. vim.inspect(args), vim.log.levels.DEBUG)
  
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
      vim.notify("Claude process exited - code: " .. tostring(code) .. ", signal: " .. tostring(signal), vim.log.levels.DEBUG)
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
      
      -- If we have output but no result callback was triggered, show it as fallback
      if output_buffer ~= "" and not callbacks._result_triggered then
        -- Try to extract meaningful content from the output
        local content = output_buffer
        
        -- Try to parse as JSON first
        local ok, json_result = pcall(vim.json.decode, output_buffer)
        if ok and json_result then
          if json_result.content then
            content = json_result.content
          elseif json_result.message then
            content = json_result.message
          end
        end
        
        if callbacks.on_result then
          callbacks.on_result({ content = content })
        end
      end
      
      current_process = nil
      current_stdin = nil
      
      if callbacks.on_exit then
        callbacks.on_exit(code, signal)
      end
    end)
  end)
  
  if not current_process then
    vim.notify("Failed to start Claude Code CLI", vim.log.levels.ERROR)
    return false
  end
  
  -- Set a timer to trigger on_start if we don't get init event
  vim.defer_fn(function()
    if not callbacks._start_triggered and callbacks.on_start then
      callbacks._start_triggered = true
      callbacks.on_start()
    end
  end, 500) -- 500ms delay
  
  -- Read stdout line by line for streaming
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Error reading Claude output: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data then
      -- Also accumulate raw output as fallback
      output_buffer = output_buffer .. data
      
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
  
  -- Store stdin handle for permission responses
  current_stdin = stdin
  
  -- Write prompt to stdin if needed
  if use_stdin and prompt then
    stdin:write(prompt, function(err)
      if err then
        vim.schedule(function()
          vim.notify("Error writing to stdin: " .. err, vim.log.levels.ERROR)
        end)
      end
      -- Keep stdin open for potential permission responses
    end)
  end
  
  return true
end

function M.stop()
  if current_process then
    current_process:kill("sigterm")
    current_process = nil
  end
  if current_stdin then
    pcall(function() current_stdin:close() end)
    current_stdin = nil
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