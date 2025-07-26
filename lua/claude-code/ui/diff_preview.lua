-- Diff preview system for reviewing changes before applying
local M = {}
local api = vim.api

M.state = {
  win = nil,
  buf = nil,
  original_buf = nil,
  changes = nil,
  callback = nil,
}

-- Create diff preview window
function M.show(changes, callback)
  -- Store the changes and callback
  M.state.changes = changes
  M.state.callback = callback
  M.state.original_buf = api.nvim_get_current_buf()
  
  -- Create preview buffer
  M.state.buf = api.nvim_create_buf(false, true)
  vim.bo[M.state.buf].buftype = 'nofile'
  vim.bo[M.state.buf].filetype = 'diff'
  vim.bo[M.state.buf].modifiable = false
  
  -- Calculate window size
  local width = math.min(100, math.floor(vim.o.columns * 0.8))
  local height = math.min(40, math.floor(vim.o.lines * 0.8))
  
  -- Create floating window
  M.state.win = api.nvim_open_win(M.state.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Claude Code Changes ',
    title_pos = 'center',
    footer = ' [Enter] Accept All | [a] Accept Line | [r] Reject Line | [q/Esc] Cancel ',
    footer_pos = 'center',
  })
  
  -- Set up syntax highlighting
  vim.wo[M.state.win].number = true
  vim.wo[M.state.win].relativenumber = false
  vim.wo[M.state.win].cursorline = true
  vim.wo[M.state.win].signcolumn = 'yes'
  
  -- Render the diff
  M._render_diff()
  
  -- Set up keymaps
  M._setup_keymaps()
  
  -- Set up highlights
  M._setup_highlights()
end

-- Render diff content
function M._render_diff()
  local lines = {}
  local highlights = {}
  
  -- Add header
  table.insert(lines, "=== Claude Code Proposed Changes ===")
  table.insert(lines, "")
  
  if M.state.changes.file then
    table.insert(lines, "File: " .. M.state.changes.file)
    table.insert(lines, "")
  end
  
  -- Process diff hunks
  if M.state.changes.hunks then
    for _, hunk in ipairs(M.state.changes.hunks) do
      -- Add hunk header
      table.insert(lines, string.format("@@ -%d,%d +%d,%d @@", 
        hunk.old_start, hunk.old_lines,
        hunk.new_start, hunk.new_lines
      ))
      
      -- Add hunk lines
      for _, line in ipairs(hunk.lines) do
        local line_text = line.text
        local line_num = #lines + 1
        
        if line.type == 'add' then
          table.insert(lines, "+" .. line_text)
          table.insert(highlights, {
            line = line_num - 1,
            col_start = 0,
            col_end = -1,
            hl_group = 'DiffAdd'
          })
        elseif line.type == 'delete' then
          table.insert(lines, "-" .. line_text)
          table.insert(highlights, {
            line = line_num - 1,
            col_start = 0,
            col_end = -1,
            hl_group = 'DiffDelete'
          })
        elseif line.type == 'context' then
          table.insert(lines, " " .. line_text)
        end
        
        -- Store line metadata for partial acceptance
        line.line_number = line_num
      end
      
      table.insert(lines, "")
    end
  elseif M.state.changes.unified_diff then
    -- Parse unified diff format
    for line in M.state.changes.unified_diff:gmatch("[^\n]+") do
      local line_num = #lines + 1
      table.insert(lines, line)
      
      if line:match("^%+") and not line:match("^%+%+%+") then
        table.insert(highlights, {
          line = line_num - 1,
          col_start = 0,
          col_end = -1,
          hl_group = 'DiffAdd'
        })
      elseif line:match("^%-") and not line:match("^%-%-%- ") then
        table.insert(highlights, {
          line = line_num - 1,
          col_start = 0,
          col_end = -1,
          hl_group = 'DiffDelete'
        })
      elseif line:match("^@@") then
        table.insert(highlights, {
          line = line_num - 1,
          col_start = 0,
          col_end = -1,
          hl_group = 'DiffChange'
        })
      end
    end
  end
  
  -- Add summary
  table.insert(lines, "")
  table.insert(lines, "=== Summary ===")
  if M.state.changes.summary then
    for _, summary_line in ipairs(vim.split(M.state.changes.summary, '\n')) do
      table.insert(lines, summary_line)
    end
  else
    local add_count = 0
    local delete_count = 0
    for _, line in ipairs(lines) do
      if line:match("^%+") and not line:match("^%+%+%+") then
        add_count = add_count + 1
      elseif line:match("^%-") and not line:match("^%-%-%- ") then
        delete_count = delete_count + 1
      end
    end
    table.insert(lines, string.format("+%d additions, -%d deletions", add_count, delete_count))
  end
  
  -- Set buffer content
  vim.bo[M.state.buf].modifiable = true
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.bo[M.state.buf].modifiable = false
  
  -- Apply highlights
  local ns_id = api.nvim_create_namespace('claude_diff_preview')
  for _, hl in ipairs(highlights) do
    api.nvim_buf_add_highlight(
      M.state.buf,
      ns_id,
      hl.hl_group,
      hl.line,
      hl.col_start,
      hl.col_end
    )
  end
end

-- Set up keymaps for the preview window
function M._setup_keymaps()
  local opts = { buffer = M.state.buf, silent = true }
  
  -- Accept all changes
  vim.keymap.set('n', '<CR>', function()
    M._accept_all()
  end, opts)
  
  -- Accept current line
  vim.keymap.set('n', 'a', function()
    M._accept_line()
  end, opts)
  
  -- Reject current line
  vim.keymap.set('n', 'r', function()
    M._reject_line()
  end, opts)
  
  -- Cancel
  vim.keymap.set('n', 'q', function()
    M._cancel()
  end, opts)
  
  vim.keymap.set('n', '<Esc>', function()
    M._cancel()
  end, opts)
  
  -- Navigate between hunks
  vim.keymap.set('n', ']h', function()
    M._next_hunk()
  end, opts)
  
  vim.keymap.set('n', '[h', function()
    M._prev_hunk()
  end, opts)
  
  -- Show help
  vim.keymap.set('n', '?', function()
    M._show_help()
  end, opts)
end

-- Accept all changes
function M._accept_all()
  M._close()
  
  if M.state.callback then
    M.state.callback({
      action = 'accept_all',
      changes = M.state.changes,
    })
  end
end

-- Accept current line (WIP - needs line tracking)
function M._accept_line()
  local cursor = api.nvim_win_get_cursor(M.state.win)
  local line_num = cursor[1]
  
  -- TODO: Implement partial acceptance
  vim.notify("Partial acceptance not yet implemented", vim.log.levels.WARN)
end

-- Reject current line (WIP - needs line tracking)
function M._reject_line()
  local cursor = api.nvim_win_get_cursor(M.state.win)
  local line_num = cursor[1]
  
  -- TODO: Implement partial rejection
  vim.notify("Partial rejection not yet implemented", vim.log.levels.WARN)
end

-- Cancel changes
function M._cancel()
  M._close()
  
  if M.state.callback then
    M.state.callback({
      action = 'cancel',
    })
  end
end

-- Navigate to next hunk
function M._next_hunk()
  local cursor = api.nvim_win_get_cursor(M.state.win)
  local lines = api.nvim_buf_get_lines(M.state.buf, cursor[1], -1, false)
  
  for i, line in ipairs(lines) do
    if line:match("^@@") then
      api.nvim_win_set_cursor(M.state.win, {cursor[1] + i, 0})
      return
    end
  end
end

-- Navigate to previous hunk
function M._prev_hunk()
  local cursor = api.nvim_win_get_cursor(M.state.win)
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, cursor[1] - 1, false)
  
  for i = #lines, 1, -1 do
    if lines[i]:match("^@@") then
      api.nvim_win_set_cursor(M.state.win, {i, 0})
      return
    end
  end
end

-- Show help
function M._show_help()
  local help_text = [[
Claude Code Diff Preview - Keyboard Shortcuts

Navigation:
  j/k         - Move up/down
  ]h          - Next hunk
  [h          - Previous hunk
  
Actions:
  <Enter>     - Accept all changes
  a           - Accept current line (coming soon)
  r           - Reject current line (coming soon)
  q/<Esc>     - Cancel and close
  
Other:
  ?           - Show this help
  
Note: Partial acceptance/rejection is still in development.
Press any key to close this help.
  ]]
  
  vim.notify(help_text, vim.log.levels.INFO)
end

-- Set up highlights
function M._setup_highlights()
  -- Ensure diff highlights are visible
  vim.cmd([[
    highlight link ClaudeDiffAdd DiffAdd
    highlight link ClaudeDiffDelete DiffDelete
    highlight link ClaudeDiffChange DiffChange
    highlight link ClaudeDiffContext Normal
  ]])
end

-- Close the preview window
function M._close()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_close(M.state.win, true)
  end
  
  if M.state.buf and api.nvim_buf_is_valid(M.state.buf) then
    api.nvim_buf_delete(M.state.buf, { force = true })
  end
  
  M.state = {
    win = nil,
    buf = nil,
    original_buf = nil,
    changes = nil,
    callback = nil,
  }
end

-- Check if preview is active
function M.is_active()
  return M.state.win ~= nil and api.nvim_win_is_valid(M.state.win)
end

return M