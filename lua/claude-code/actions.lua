local M = {}
local process = require('claude-code.process')
local streaming = require('claude-code.streaming')
local context = require('claude-code.context')

local stream_parser = nil

function M.init()
  stream_parser = streaming:new()
end

function M.complete_at_cursor()
  if not process.is_running() then
    vim.notify("Claude Code not running. Use :ClaudeCode start", vim.log.levels.WARN)
    return
  end
  
  local ctx = context.gather_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  
  -- Get content up to cursor
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor[1], false)
  if cursor[2] > 0 and #lines > 0 then
    lines[#lines] = lines[#lines]:sub(1, cursor[2])
  end
  
  local prefix = table.concat(lines, '\n')
  
  M.send_request({
    type = 'complete',
    prefix = prefix,
    suffix = '', -- Could add content after cursor
    file = ctx.current_file,
    language = ctx.filetype,
  }, function(response)
    if response.suggestion then
      require('claude-code.ui.inline').show_suggestion(bufnr, cursor[1], response.suggestion)
    end
  end)
end

function M.edit_selection(instruction)
  local selection = context.get_visual_selection()
  if not selection then
    vim.notify("No selection found", vim.log.levels.WARN)
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx = context.gather_context()
  
  -- Get instruction from user if not provided
  if not instruction or instruction == '' then
    vim.ui.input({
      prompt = 'Edit instruction: ',
    }, function(input)
      if input and input ~= '' then
        M._perform_edit(bufnr, selection, input, ctx)
      end
    end)
  else
    M._perform_edit(bufnr, selection, instruction, ctx)
  end
end

function M._perform_edit(bufnr, selection, instruction, ctx)
  M.send_request({
    type = 'edit',
    code = selection.text,
    instruction = instruction,
    file = ctx.current_file,
    language = ctx.filetype,
    start_line = selection.start_line,
    end_line = selection.end_line,
  }, function(response)
    if response.replacement then
      -- Get original lines for diff
      local original_lines = vim.split(selection.text, '\n', {plain = true})
      local new_lines = vim.split(response.replacement, '\n', {plain = true})
      
      -- Create diff preview
      local changes = {
        file = ctx.current_file,
        hunks = {{
          old_start = selection.start_line,
          old_lines = #original_lines,
          new_start = selection.start_line,
          new_lines = #new_lines,
          lines = M._create_diff_lines(original_lines, new_lines),
        }},
        summary = response.summary or instruction,
      }
      
      -- Show diff preview
      require('claude-code.ui.diff_preview').show(changes, function(result)
        if result.action == 'accept_all' then
          -- Apply the changes
          vim.api.nvim_buf_set_lines(
            bufnr,
            selection.start_line - 1,
            selection.end_line,
            false,
            new_lines
          )
          vim.notify("Edit applied successfully", vim.log.levels.INFO)
        else
          vim.notify("Edit cancelled", vim.log.levels.INFO)
        end
      end)
    elseif response.error then
      vim.notify("Edit failed: " .. response.error, vim.log.levels.ERROR)
    end
  end)
end

-- Helper to create diff lines
function M._create_diff_lines(old_lines, new_lines)
  local diff_lines = {}
  
  -- Simple diff algorithm (for now, just show all old as removed and all new as added)
  -- TODO: Implement proper diff algorithm
  
  for _, line in ipairs(old_lines) do
    table.insert(diff_lines, {
      type = 'delete',
      text = line,
    })
  end
  
  for _, line in ipairs(new_lines) do
    table.insert(diff_lines, {
      type = 'add',
      text = line,
    })
  end
  
  return diff_lines
end

function M.send_request(request, callback)
  if not stream_parser then
    M.init()
  end
  
  -- Store callback for this request
  local request_id = vim.fn.localtime() .. '_' .. math.random(1000)
  request.id = request_id
  
  -- Set up response handler
  local response_handler = function(data)
    local messages = stream_parser:feed(data)
    for _, msg in ipairs(messages) do
      if msg.id == request_id then
        callback(msg)
      end
    end
  end
  
  -- Temporarily store handler
  _G.ClaudeCodeHandlers = _G.ClaudeCodeHandlers or {}
  _G.ClaudeCodeHandlers[request_id] = response_handler
  
  -- Send request
  if not process.send(request) then
    vim.notify("Failed to send request to Claude Code", vim.log.levels.ERROR)
    _G.ClaudeCodeHandlers[request_id] = nil
  end
end

-- Get completions for nvim-cmp
function M.get_completions(request, callback)
  if not process.is_running() then
    callback({ items = {}, isIncomplete = false })
    return
  end
  
  M.send_request({
    type = 'completions',
    context = request,
    max_items = 20,
  }, function(response)
    if response.error then
      callback({ items = {}, isIncomplete = false })
    else
      callback(response)
    end
  end)
end

-- Preview a completion before applying
function M.preview_completion(request, callback)
  M.send_request({
    type = 'preview_completion',
    item = request.item,
  }, callback)
end

-- Semantic search across project
function M.semantic_search(request, callback)
  M.send_request({
    type = 'semantic_search',
    query = request.query,
    project_root = request.project_root or vim.fn.getcwd(),
    max_results = request.max_results or 50,
  }, callback)
end

-- Generate commit message
function M.generate_commit_message(request, callback)
  M.send_request({
    type = 'generate_commit_message',
    changes = request.changes,
    style = request.type or 'conventional',
  }, callback)
end

-- Generate PR description
function M.generate_pr_description(request, callback)
  M.send_request({
    type = 'generate_pr_description',
    diff = request.diff,
    commits = request.commits,
  }, callback)
end

-- Explain symbol or code
function M.explain_symbol(symbol)
  local ctx = context.gather_context()
  M.send_request({
    type = 'explain',
    symbol = symbol,
    context = ctx,
  }, function(response)
    if response.explanation then
      require('claude-code.ui.explanation').show(response.explanation)
    end
  end)
end

-- Fix diagnostic
function M.fix_diagnostic(request)
  M.send_request({
    type = 'fix_diagnostic',
    diagnostic = request.diagnostic,
    file = request.file,
    line = request.line,
  }, function(response)
    if response.fix then
      require('claude-code.ui.diff_preview').show(response.fix)
    end
  end)
end

-- Analyze debug state
function M.analyze_debug_state(request)
  M.send_request({
    type = 'analyze_debug',
    variables = request.variables,
    breakpoints = request.breakpoints,
  }, function(response)
    if response.analysis then
      require('claude-code.ui.debug_analysis').show(response.analysis)
    end
  end)
end

-- Set up process callbacks
function M.start()
  if not stream_parser then
    M.init()
  end
  
  process.spawn({}, {
    on_stdout = function(data)
      -- Distribute to all active handlers
      if _G.ClaudeCodeHandlers then
        for _, handler in pairs(_G.ClaudeCodeHandlers) do
          handler(data)
        end
      end
    end,
    
    on_stderr = function(data)
      vim.notify("Claude Code stderr: " .. data, vim.log.levels.WARN)
    end,
    
    on_exit = function(code, signal)
      if code ~= 0 then
        vim.notify(string.format("Claude Code exited with code %d", code), vim.log.levels.ERROR)
      end
      -- Clear handlers
      _G.ClaudeCodeHandlers = {}
    end,
  })
  
  vim.notify("Claude Code started", vim.log.levels.INFO)
end

function M.stop()
  process.stop()
  _G.ClaudeCodeHandlers = {}
  vim.notify("Claude Code stopped", vim.log.levels.INFO)
end

function M.status()
  if process.is_running() then
    vim.notify("Claude Code is running", vim.log.levels.INFO)
  else
    vim.notify("Claude Code is not running", vim.log.levels.WARN)
  end
end

return M