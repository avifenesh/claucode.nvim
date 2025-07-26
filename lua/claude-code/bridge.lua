-- Bridge between Neovim and Claude Code CLI
local M = {}
local uv = vim.loop

M.config = {}
M.state = {
  -- Track what we've shared with Claude
  shared_files = {},
  last_prompt = nil,
  claude_working = false,
}

function M.init(config)
  M.config = config
  
  -- Create communication files
  M._ensure_bridge_files()
  
  -- Start monitoring Claude's status
  M._monitor_claude_status()
end

-- Send a prompt to Claude Code
function M.send_prompt(text)
  -- Store the prompt
  M.state.last_prompt = text
  
  -- Write prompt to shared file
  local prompt_file = M.config.bridge.shared_dir .. '/prompt.txt'
  local context_file = M.config.bridge.shared_dir .. '/context.json'
  
  -- Gather context
  local context = M._gather_context()
  
  -- Write context
  vim.fn.writefile({vim.json.encode(context)}, context_file)
  
  -- Write prompt
  vim.fn.writefile({text}, prompt_file)
  
  -- Notify user
  vim.notify("Sent to Claude: " .. text, vim.log.levels.INFO)
  
  -- Mark Claude as working
  M.state.claude_working = true
  
  -- Show instructions if Claude not connected
  if not M._is_claude_connected() then
    vim.notify("Run this in Claude Code terminal: /look " .. prompt_file, vim.log.levels.WARN)
  end
end

-- Share current context with Claude
function M.share_current_context()
  local context = M._gather_context()
  local context_file = M.config.bridge.shared_dir .. '/context.json'
  
  -- Write detailed context
  local detailed_context = {
    timestamp = os.time(),
    current_file = vim.api.nvim_buf_get_name(0),
    cursor_position = vim.api.nvim_win_get_cursor(0),
    visible_lines = M._get_visible_lines(),
    diagnostics = M._get_diagnostics(),
    git_status = M._get_git_status(),
    open_buffers = M._get_open_buffers(),
  }
  
  vim.fn.writefile({vim.json.encode(detailed_context)}, context_file)
  
  -- Update shared files tracking
  M.state.shared_files[detailed_context.current_file] = os.time()
  
  vim.notify("Shared context with Claude Code", vim.log.levels.INFO)
end

-- Share selection with Claude
function M.share_selection(selection_context)
  local context_file = M.config.bridge.shared_dir .. '/context.json'
  
  -- Write selection context
  local detailed_context = {
    timestamp = os.time(),
    type = 'selection',
    selection = selection_context,
    current_file = selection_context.file,
    diagnostics = M._get_diagnostics(),
    git_status = M._get_git_status(),
  }
  
  vim.fn.writefile({vim.json.encode(detailed_context)}, context_file)
  
  -- Update shared files tracking
  M.state.shared_files[selection_context.file] = os.time()
  
  vim.notify("Shared selection with Claude Code", vim.log.levels.INFO)
end

-- Gather basic context
function M._gather_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  
  local context = {
    file = vim.api.nvim_buf_get_name(bufnr),
    filetype = vim.bo[bufnr].filetype,
    cursor = vim.api.nvim_win_get_cursor(0),
  }
  
  -- Add selection if in visual mode
  if mode == 'v' or mode == 'V' then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2]-1, end_pos[2], false)
    context.selection = {
      text = table.concat(lines, '\n'),
      start_line = start_pos[2],
      end_line = end_pos[2],
    }
  end
  
  -- Add current line
  context.current_line = vim.api.nvim_get_current_line()
  
  return context
end

-- Get visible lines in window
function M._get_visible_lines()
  local win = vim.api.nvim_get_current_win()
  local top = vim.fn.line('w0')
  local bottom = vim.fn.line('w$')
  local bufnr = vim.api.nvim_win_get_buf(win)
  
  return {
    top = top,
    bottom = bottom,
    lines = vim.api.nvim_buf_get_lines(bufnr, top-1, bottom, false),
  }
end

-- Get current diagnostics
function M._get_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(bufnr)
  
  local formatted = {}
  for _, diag in ipairs(diagnostics) do
    table.insert(formatted, {
      line = diag.lnum + 1,
      message = diag.message,
      severity = diag.severity,
      source = diag.source,
    })
  end
  
  return formatted
end

-- Get git status
function M._get_git_status()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then return nil end
  
  local status = vim.fn.system('git status --porcelain ' .. vim.fn.shellescape(file))
  if vim.v.shell_error == 0 then
    return vim.trim(status)
  end
  return nil
end

-- Get open buffers
function M._get_open_buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' then
        table.insert(buffers, {
          id = buf,
          name = name,
          modified = vim.bo[buf].modified,
        })
      end
    end
  end
  return buffers
end

-- Ensure bridge files exist
function M._ensure_bridge_files()
  local files = {
    '/prompt.txt',
    '/context.json',
    '/status.json',
    '/changes.json',
  }
  
  for _, file in ipairs(files) do
    local path = M.config.bridge.shared_dir .. file
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile({''}, path)
    end
  end
end

-- Check if Claude is connected
function M._is_claude_connected()
  local status_file = M.config.bridge.shared_dir .. '/status.json'
  if vim.fn.filereadable(status_file) == 1 then
    local content = vim.fn.readfile(status_file)
    if #content > 0 then
      local ok, status = pcall(vim.json.decode, content[1])
      if ok and status.connected then
        return true
      end
    end
  end
  return false
end

-- Monitor Claude's status
function M._monitor_claude_status()
  -- This could be enhanced to watch for status file changes
  -- For now, just check periodically when actions are performed
end

-- Handle incoming changes from Claude
function M.handle_changes(changes)
  if M.config.watcher.diff_preview then
    require('claude-code.review').preview_changes(changes)
  else
    -- Auto-apply changes
    for _, change in ipairs(changes.files) do
      if change.action == 'modify' then
        vim.cmd('checktime ' .. change.path)
      end
    end
  end
end

return M