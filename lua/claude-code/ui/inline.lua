local M = {}
local config = require('claude-code.config')

M.state = {
  active = false,
  bufnr = nil,
  line = nil,
  suggestion = nil,
  ns_id = nil,
}

function M.init()
  M.state.ns_id = vim.api.nvim_create_namespace('claude_code_suggestions')
end

function M.show_suggestion(bufnr, line, suggestion)
  if not config.get().ui.inline.enabled then
    return
  end
  
  -- Initialize namespace if needed
  if not M.state.ns_id then
    M.init()
  end
  
  -- Clear any existing suggestion
  M.clear()
  
  -- Store state
  M.state.active = true
  M.state.bufnr = bufnr
  M.state.line = line
  M.state.suggestion = suggestion
  
  -- Show virtual text
  local opts = config.get().ui.inline
  vim.api.nvim_buf_set_extmark(bufnr, M.state.ns_id, line - 1, -1, {
    virt_text = {{suggestion, opts.highlight}},
    virt_text_pos = 'overlay',
    ephemeral = false,
    priority = opts.priority,
    id = 1,
  })
end

function M.accept_suggestion()
  if not M.state.active or not M.state.suggestion then
    return false
  end
  
  local bufnr = M.state.bufnr
  local line = M.state.line
  local suggestion = M.state.suggestion
  
  -- Get current line content
  local current_line = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
  
  -- Insert suggestion
  vim.api.nvim_buf_set_lines(bufnr, line - 1, line, false, {current_line .. suggestion})
  
  -- Move cursor to end of inserted text
  local new_col = #current_line + #suggestion
  vim.api.nvim_win_set_cursor(0, {line, new_col})
  
  M.clear()
  return true
end

function M.dismiss_suggestion()
  if not M.state.active then
    return false
  end
  
  M.clear()
  return true
end

function M.clear()
  if M.state.ns_id and M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    vim.api.nvim_buf_clear_namespace(M.state.bufnr, M.state.ns_id, 0, -1)
  end
  
  M.state.active = false
  M.state.bufnr = nil
  M.state.line = nil
  M.state.suggestion = nil
end

-- Auto-clear on cursor move
vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
  group = vim.api.nvim_create_augroup('ClaudeCodeInline', { clear = true }),
  callback = function()
    if M.state.active then
      local cursor = vim.api.nvim_win_get_cursor(0)
      if cursor[1] ~= M.state.line then
        M.clear()
      end
    end
  end,
})

return M