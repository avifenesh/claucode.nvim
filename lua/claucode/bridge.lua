local M = {}

local uv = vim.loop
local current_process = nil
local output_buffer = ""
local callbacks = {}

local function create_temp_file(content)
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  local temp_file = temp_dir .. "/claude_input.txt"
  vim.fn.writefile(vim.split(content, "\n"), temp_file)
  return temp_file
end

local function parse_claude_output(data)
  output_buffer = output_buffer .. data
  
  -- Look for file modifications in the output
  local modifications = {}
  
  -- Pattern to match file paths that Claude might be working on
  local file_pattern = "File: ([^\n]+)"
  for file in output_buffer:gmatch(file_pattern) do
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

function M.send_to_claude(prompt, opts)
  opts = opts or {}
  local config = require("claucode").get_config()
  
  -- Build command arguments
  local args = {}
  
  -- Add model if specified
  if config.model then
    table.insert(args, "--model")
    table.insert(args, config.model)
  end
  
  -- Add the prompt
  if prompt and prompt ~= "" then
    -- For complex prompts, use a temp file
    if #prompt > 1000 or prompt:match("\n") then
      local temp_file = create_temp_file(prompt)
      table.insert(args, "-p")
      table.insert(args, "@" .. temp_file)
    else
      table.insert(args, "-p")
      table.insert(args, prompt)
    end
  end
  
  -- Add current file context if requested
  if opts.include_current_file then
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename ~= "" then
      table.insert(args, filename)
    end
  end
  
  -- Reset output buffer
  output_buffer = ""
  
  -- Create pipes for process communication
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local stdin = uv.new_pipe(false)
  
  -- Spawn the Claude process
  current_process = uv.spawn(config.command, {
    args = args,
    stdio = {stdin, stdout, stderr},
    cwd = vim.fn.getcwd(),
  }, function(code, signal)
    -- Process exit callback
    vim.schedule(function()
      if code ~= 0 then
        vim.notify("Claude Code exited with code: " .. code, vim.log.levels.ERROR)
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
      vim.schedule(function()
        parse_claude_output(data)
      end)
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
      vim.schedule(function()
        vim.notify("Claude: " .. data, vim.log.levels.WARN)
      end)
    end
  end)
  
  -- Close stdin as we're not using it for interactive communication
  stdin:close()
  
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