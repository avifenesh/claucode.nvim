-- Review system for Claude Code changes
local M = {}

M.state = {
  pending_changes = {},
  diff_bufnr = nil,
  original_bufnr = nil,
}

-- Show all pending changes
function M.show()
  local config = require('claude-code').config
  local changes_file = config.bridge.shared_dir .. '/changes.json'
  
  if vim.fn.filereadable(changes_file) == 0 then
    vim.notify("No pending changes from Claude Code", vim.log.levels.INFO)
    return
  end
  
  local content = vim.fn.readfile(changes_file)
  if #content == 0 then
    vim.notify("No pending changes from Claude Code", vim.log.levels.INFO)
    return
  end
  
  local ok, changes = pcall(vim.json.decode, content[1])
  if not ok then
    vim.notify("Failed to parse changes file", vim.log.levels.ERROR)
    return
  end
  
  M.show_changes(changes)
end

-- Show changes in review interface
function M.show_changes(changes)
  if not changes.files or #changes.files == 0 then
    vim.notify("No file changes to review", vim.log.levels.INFO)
    return
  end
  
  -- Store pending changes
  M.state.pending_changes = changes
  
  -- Create review buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'claude-review'
  
  -- Build review content
  local lines = {
    '# Claude Code Changes Review',
    '',
    'Message: ' .. (changes.message or 'No message'),
    'Files: ' .. #changes.files,
    '',
    'Commands:',
    '  <CR> - Preview file changes',
    '  a    - Accept all changes',
    '  r    - Reject all changes',
    '  q    - Close review',
    '',
    'Files:',
  }
  
  -- List files
  for i, file in ipairs(changes.files) do
    local status = file.action or 'modify'
    local mark = status == 'create' and '[+]' or status == 'delete' and '[-]' or '[M]'
    table.insert(lines, string.format('  %d. %s %s', i, mark, file.path))
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Open in split
  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, buf)
  
  -- Set up keymaps
  M._setup_review_keymaps(buf)
end

-- Preview changes for a specific file
function M.preview_file_changes(bufnr, change)
  -- Save original buffer
  M.state.original_bufnr = bufnr
  
  -- Create diff view
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_lines = {}
  
  if change.content then
    -- Content provided
    new_lines = vim.split(change.content, '\n')
  elseif change.path then
    -- Read from file
    new_lines = vim.fn.readfile(change.path)
  end
  
  -- Create buffers for diff
  local orig_buf = vim.api.nvim_create_buf(false, true)
  local new_buf = vim.api.nvim_create_buf(false, true)
  
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, original_lines)
  vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, new_lines)
  
  -- Set filetype for syntax highlighting
  local ft = vim.bo[bufnr].filetype
  vim.bo[orig_buf].filetype = ft
  vim.bo[new_buf].filetype = ft
  
  -- Open diff view
  vim.cmd('tabnew')
  vim.cmd('vsplit')
  
  -- Left side - original
  vim.api.nvim_win_set_buf(0, orig_buf)
  vim.cmd('diffthis')
  
  -- Right side - new
  vim.cmd('wincmd l')
  vim.api.nvim_win_set_buf(0, new_buf)
  vim.cmd('diffthis')
  
  -- Store for cleanup
  M.state.diff_bufnr = { orig_buf, new_buf }
  
  -- Add status line
  vim.wo.statusline = 'Claude Changes - [a]ccept [r]eject [q]uit'
  
  -- Set up diff keymaps
  M._setup_diff_keymaps(new_buf, change)
end

-- Setup keymaps for review buffer
function M._setup_review_keymaps(buf)
  local opts = { buffer = buf, silent = true }
  
  -- Preview file under cursor
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local num = line:match('^%s*(%d+)%.')
    if num then
      local change = M.state.pending_changes.files[tonumber(num)]
      if change then
        M.preview_file_changes(vim.fn.bufnr(change.path), change)
      end
    end
  end, opts)
  
  -- Accept all changes
  vim.keymap.set('n', 'a', function()
    M._accept_all_changes()
  end, opts)
  
  -- Reject all changes
  vim.keymap.set('n', 'r', function()
    M._reject_all_changes()
  end, opts)
  
  -- Quit
  vim.keymap.set('n', 'q', function()
    vim.cmd('bdelete!')
  end, opts)
end

-- Setup keymaps for diff view
function M._setup_diff_keymaps(buf, change)
  local opts = { buffer = buf, silent = true }
  
  -- Accept changes
  vim.keymap.set('n', 'a', function()
    -- Apply the change
    if change.path and change.content then
      vim.fn.writefile(vim.split(change.content, '\n'), change.path)
      vim.notify('Accepted changes to ' .. change.path, vim.log.levels.INFO)
    end
    
    -- Clean up
    vim.cmd('tabclose')
    M._cleanup_diff()
  end, opts)
  
  -- Reject changes
  vim.keymap.set('n', 'r', function()
    vim.notify('Rejected changes', vim.log.levels.INFO)
    vim.cmd('tabclose')
    M._cleanup_diff()
  end, opts)
  
  -- Quit
  vim.keymap.set('n', 'q', function()
    vim.cmd('tabclose')
    M._cleanup_diff()
  end, opts)
end

-- Accept all pending changes
function M._accept_all_changes()
  for _, change in ipairs(M.state.pending_changes.files or {}) do
    if change.action == 'modify' and change.content then
      vim.fn.writefile(vim.split(change.content, '\n'), change.path)
    elseif change.action == 'create' and change.content then
      vim.fn.writefile(vim.split(change.content, '\n'), change.path)
    elseif change.action == 'delete' then
      vim.fn.delete(change.path)
    end
  end
  
  vim.notify('Accepted all changes', vim.log.levels.INFO)
  M._clear_changes()
  vim.cmd('bdelete!')
end

-- Reject all pending changes
function M._reject_all_changes()
  vim.notify('Rejected all changes', vim.log.levels.INFO)
  M._clear_changes()
  vim.cmd('bdelete!')
end

-- Clear changes file
function M._clear_changes()
  local config = require('claude-code').config
  local changes_file = config.bridge.shared_dir .. '/changes.json'
  vim.fn.writefile({''}, changes_file)
  M.state.pending_changes = {}
end

-- Clean up diff buffers
function M._cleanup_diff()
  if M.state.diff_bufnr then
    for _, buf in ipairs(M.state.diff_bufnr) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    M.state.diff_bufnr = nil
  end
end

return M