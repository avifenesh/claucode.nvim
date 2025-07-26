local M = {}

-- Helper to create a test buffer
function M.create_buf(content, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  
  if content then
    local lines = type(content) == 'string' and vim.split(content, '\n') or content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  
  return buf
end

-- Helper to set visual selection
function M.set_visual_selection(buf, start_line, start_col, end_line, end_col)
  vim.api.nvim_buf_set_mark(buf, '<', start_line, start_col, {})
  vim.api.nvim_buf_set_mark(buf, '>', end_line, end_col, {})
  vim.fn.setpos("'<", {buf, start_line, start_col + 1, 0})
  vim.fn.setpos("'>", {buf, end_line, end_col + 1, 0})
end

-- Helper to wait for async operations
function M.wait(ms)
  vim.wait(ms or 10)
end

-- Helper to capture notifications
function M.capture_notifications()
  local notifications = {}
  local original_notify = vim.notify
  
  vim.notify = function(msg, level)
    table.insert(notifications, {msg = msg, level = level})
  end
  
  return {
    notifications = notifications,
    restore = function()
      vim.notify = original_notify
    end
  }
end

return M