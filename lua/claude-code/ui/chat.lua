local M = {}
local config = require('claude-code.config')

M.state = {
  buf = nil,
  win = nil,
  messages = {},
}

function M.create_window()
  local opts = config.get().ui.chat
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'claude-chat'
  
  -- Calculate window dimensions
  local width = math.floor(vim.o.columns * opts.width)
  local height = math.floor(vim.o.lines * opts.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = opts.border,
    title = opts.title,
    title_pos = opts.title_pos,
  })
  
  -- Set window options
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].cursorline = true
  
  -- Set up keymaps
  M.setup_keymaps(buf)
  
  M.state.buf = buf
  M.state.win = win
  
  return buf, win
end

function M.setup_keymaps(buf)
  local opts = { buffer = buf, silent = true }
  
  -- Close window
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)
  
  -- Send message
  vim.keymap.set('n', '<CR>', function() M.send_message() end, opts)
  vim.keymap.set('i', '<C-CR>', function() M.send_message() end, opts)
  
  -- Clear chat
  vim.keymap.set('n', '<C-l>', function() M.clear() end, opts)
end

function M.open(initial_message)
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    return
  end
  
  M.create_window()
  M.render()
  
  if initial_message then
    M.add_message('user', initial_message)
    M.send_to_claude(initial_message)
  end
  
  -- Enter insert mode at the end
  vim.cmd('normal! G')
  vim.cmd('startinsert')
end

function M.close()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.win = nil
end

function M.toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    M.close()
  else
    M.open()
  end
end

function M.add_message(role, content)
  table.insert(M.state.messages, {
    role = role,
    content = content,
    timestamp = os.time(),
  })
  M.render()
end

function M.render()
  if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
    return
  end
  
  local lines = {}
  
  for _, msg in ipairs(M.state.messages) do
    local prefix = msg.role == 'user' and '👤 You:' or '🤖 Claude:'
    table.insert(lines, prefix)
    
    -- Split content by newlines and indent
    for line in msg.content:gmatch('[^\n]+') do
      table.insert(lines, '   ' .. line)
    end
    
    table.insert(lines, '')
  end
  
  -- Add input prompt
  table.insert(lines, '─────────────────────────────')
  table.insert(lines, '💬 Your message:')
  table.insert(lines, '')
  
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
end

function M.send_message()
  if not M.state.buf then return end
  
  -- Get the input (last lines after the separator)
  local lines = vim.api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local separator_line = nil
  
  for i = #lines, 1, -1 do
    if lines[i]:match('^─+$') then
      separator_line = i
      break
    end
  end
  
  if not separator_line then return end
  
  -- Extract message lines
  local message_lines = {}
  for i = separator_line + 2, #lines do
    if lines[i] and lines[i] ~= '' then
      table.insert(message_lines, lines[i])
    end
  end
  
  local message = table.concat(message_lines, '\n')
  if message == '' then return end
  
  M.add_message('user', message)
  M.send_to_claude(message)
end

function M.send_to_claude(message)
  local context = require('claude-code.context').gather_context()
  
  require('claude-code.actions').send_request({
    type = 'chat',
    message = message,
    context = context,
  }, function(response)
    if response.error then
      M.add_message('assistant', 'Error: ' .. response.error)
    else
      M.add_message('assistant', response.content or 'No response')
    end
  end)
end

function M.clear()
  M.state.messages = {}
  M.render()
end

return M