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
  
  -- First check if it's plain text output (not JSON)
  if not line:match("^%s*{") then
    -- Handle as plain text
    if callbacks.on_stream and line ~= "" then
      callbacks.on_stream(line)
    end
    return
  end
  
  -- Try to parse as JSON
  local ok, result = pcall(vim.json.decode, line)
  if not ok then 
    -- If not JSON, treat as plain text
    if callbacks.on_stream and not line:match("^%s*$") then
      callbacks.on_stream(line)
    end
    return 
  end
  
  -- Only log non-routine events for debugging
  vim.schedule(function()
    if result.type and result.type ~= "assistant" and result.type ~= "text" and result.type ~= "content" then
      vim.notify("Claude event: " .. result.type .. (result.subtype and ("/" .. result.subtype) or ""), vim.log.levels.DEBUG)
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
          -- Only log non-standard tool use for debugging
          if content.name and not content.name:match("^(Edit|Write|Read|Bash)$") then
            vim.schedule(function()
              vim.notify("Tool use: " .. content.name, vim.log.levels.DEBUG)
            end)
          end
          
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
  
  -- For complex prompts, we'll use stdin
  local use_stdin = #prompt > 1000 or prompt:match("\n")
  
  -- Build command arguments
  local args = {}
  
  -- Use print mode for non-interactive output
  table.insert(args, "-p")
  
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
  
  -- Add the prompt as the last argument (not with -p flag)
  if prompt and prompt ~= "" and not use_stdin then
    table.insert(args, prompt)
  end
  
  -- Command logging removed - too verbose for normal use
  
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
      -- Always trigger on_result with the accumulated output
      if callbacks.on_result then
        callbacks.on_result({ content = output_buffer })
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
  
  -- Don't trigger on_start immediately - wait for actual output
  
  -- Read stdout line by line for streaming
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("Error reading Claude output: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    
    if data then
      -- Accumulate output
      output_buffer = output_buffer .. data
      
      -- For plain text mode (-p flag), stream directly
      -- But still check for potential JSON events mixed in
      local lines = vim.split(data, "\n", { plain = true })
      
      for _, line in ipairs(lines) do
        if line ~= "" then
          -- Check if it looks like JSON
          if line:match("^%s*{") then
            -- Try to parse as JSON event
            vim.schedule(function()
              parse_streaming_json(line)
            end)
          else
            -- Plain text - stream it
            if not callbacks._start_triggered and callbacks.on_start then
              callbacks._start_triggered = true
              vim.schedule(function()
                callbacks.on_start()
              end)
            end
            
            if callbacks.on_stream then
              vim.schedule(function()
                callbacks.on_stream(line .. "\n")
              end)
            end
          end
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
        -- Show errors
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
    stdin:write(prompt .. "\n", function(err)
      if err then
        vim.schedule(function()
          vim.notify("Error writing to stdin: " .. err, vim.log.levels.ERROR)
        end)
      else
        -- Close stdin after writing the prompt
        stdin:shutdown()
      end
    end)
  else
    -- For simple prompts, close stdin immediately
    stdin:close()
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