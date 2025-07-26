local M = {}

local popup_buf = nil
local popup_win = nil

function M.show_response(content)
  -- Create buffer if it doesn't exist
  if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
    popup_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(popup_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(popup_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(popup_buf, 'filetype', 'markdown')
  end
  
  -- Split content into lines
  local lines = vim.split(content, '\n')
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  
  -- Get editor dimensions
  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")
  
  -- Calculate popup size (80% of screen)
  local win_width = math.floor(width * 0.8)
  local win_height = math.floor(height * 0.8)
  
  -- Calculate position (centered)
  local row = math.floor((height - win_height) / 2)
  local col = math.floor((width - win_width) / 2)
  
  -- Create popup window
  popup_win = vim.api.nvim_open_win(popup_buf, true, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Claude Response ',
    title_pos = 'center',
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(popup_win, 'wrap', true)
  vim.api.nvim_win_set_option(popup_win, 'linebreak', true)
  
  -- Add keymaps for the popup
  local opts = { noremap = true, silent = true, buffer = popup_buf }
  vim.keymap.set('n', 'q', ':close<CR>', opts)
  vim.keymap.set('n', '<Esc>', ':close<CR>', opts)
  
  -- Scroll to top
  vim.api.nvim_win_set_cursor(popup_win, {1, 0})
end

function M.append_to_response(content)
  if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
    M.show_response(content)
    return
  end
  
  -- Append to existing buffer
  local lines = vim.split(content, '\n')
  local line_count = vim.api.nvim_buf_line_count(popup_buf)
  vim.api.nvim_buf_set_lines(popup_buf, line_count, line_count, false, lines)
end

function M.close_popup()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  popup_win = nil
end

return M