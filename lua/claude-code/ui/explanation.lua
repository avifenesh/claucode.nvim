-- Explanation window for claude-code.nvim
local M = {}

-- Show explanation in a floating window
function M.show(explanation)
  local lines = vim.split(explanation, '\n')
  
  -- Calculate window size
  local width = math.min(80, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 4, math.floor(vim.o.lines * 0.8))
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'markdown'
  
  -- Add header
  table.insert(lines, 1, '# Claude Code Explanation')
  table.insert(lines, 2, '')
  table.insert(lines, '')
  table.insert(lines, '---')
  table.insert(lines, '_Press q or <Esc> to close_')
  
  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Explanation ',
    title_pos = 'center',
  })
  
  -- Set options
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].cursorline = true
  
  -- Keymaps
  local opts = { buffer = buf, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
end

return M