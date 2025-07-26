-- Progress indicator system for claude-code.nvim
local M = {}

M.state = {
  active = false,
  message = "",
  percentage = nil,
  start_time = nil,
  spinner_index = 1,
  timer = nil,
}

-- Spinner characters
M.spinners = {
  default = {'⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'},
  dots = {'⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'},
  circle = {'◐', '◓', '◑', '◒'},
  square = {'◰', '◳', '◲', '◱'},
  moon = {'🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'},
}

-- Start progress indicator
function M.start(message, opts)
  opts = opts or {}
  
  M.state.active = true
  M.state.message = message or "Processing..."
  M.state.percentage = nil
  M.state.start_time = vim.loop.now()
  M.state.spinner_index = 1
  
  -- Get spinner from config
  local config = require('claude-code.config').get()
  local spinner_name = opts.spinner or (config.ui and config.ui.progress and config.ui.progress.spinner)
  M.state.spinner = M.spinners[spinner_name] or M.spinners.default
  
  -- Start spinner animation
  M._start_spinner()
  
  -- Update statusline
  M._update_statusline()
  
  -- Send notification if configured
  if config.ui and config.ui.progress and config.ui.progress.notify then
    vim.notify("Claude Code: " .. M.state.message, vim.log.levels.INFO)
  end
end

-- Update progress
function M.update(message, percentage)
  if not M.state.active then return end
  
  if message then
    M.state.message = message
  end
  
  if percentage then
    M.state.percentage = math.min(100, math.max(0, percentage))
  end
  
  M._update_statusline()
end

-- Stop progress indicator
function M.stop(final_message)
  if not M.state.active then return end
  
  M.state.active = false
  
  -- Stop spinner
  if M.state.timer then
    M.state.timer:stop()
    M.state.timer:close()
    M.state.timer = nil
  end
  
  -- Show completion message
  if final_message then
    local elapsed = (vim.loop.now() - M.state.start_time) / 1000
    vim.notify(string.format("%s (%.1fs)", final_message, elapsed), vim.log.levels.INFO)
  end
  
  -- Clear state
  M.state.message = ""
  M.state.percentage = nil
  M.state.start_time = nil
  
  -- Update statusline
  M._update_statusline()
end

-- Get current progress state
function M.get_current()
  if not M.state.active then return nil end
  
  return {
    message = M.state.message,
    percentage = M.state.percentage,
    elapsed = (vim.loop.now() - M.state.start_time) / 1000,
    spinner = M.state.spinner[M.state.spinner_index],
  }
end

-- Check if progress is active
function M.is_active()
  return M.state.active
end

-- Start spinner animation
function M._start_spinner()
  if M.state.timer then
    M.state.timer:stop()
    M.state.timer:close()
  end
  
  M.state.timer = vim.loop.new_timer()
  M.state.timer:start(0, 100, vim.schedule_wrap(function()
    if not M.state.active then
      if M.state.timer then
        M.state.timer:stop()
        M.state.timer:close()
        M.state.timer = nil
      end
      return
    end
    
    M.state.spinner_index = (M.state.spinner_index % #M.state.spinner) + 1
    M._update_statusline()
  end))
end

-- Update statusline
function M._update_statusline()
  -- Trigger statusline redraw
  vim.cmd('redrawstatus')
  
  -- Also update global variable for custom statuslines
  if M.state.active then
    local spinner = M.state.spinner[M.state.spinner_index]
    local text = spinner .. " " .. M.state.message
    
    if M.state.percentage then
      text = text .. string.format(" [%d%%]", M.state.percentage)
    end
    
    vim.g.claude_code_progress = text
  else
    vim.g.claude_code_progress = ""
  end
end

-- Create floating progress window (optional)
function M.show_window()
  if not M.state.active then return end
  
  local width = 40
  local height = 3
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = 1,
    col = vim.o.columns - width - 2,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
  })
  
  -- Set content
  local lines = {
    " " .. M.state.spinner[M.state.spinner_index] .. " Claude Code",
    " " .. M.state.message,
  }
  
  if M.state.percentage then
    local bar_width = width - 4
    local filled = math.floor(bar_width * M.state.percentage / 100)
    local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
    table.insert(lines, " " .. bar)
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Auto-close after progress stops
  local close_timer = vim.loop.new_timer()
  close_timer:start(100, 100, vim.schedule_wrap(function()
    if not M.state.active then
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      close_timer:stop()
      close_timer:close()
    end
  end))
end

-- Integration with lualine
function M.lualine_component()
  return function()
    local progress = M.get_current()
    if not progress then return "" end
    
    local text = progress.spinner .. " " .. progress.message
    if progress.percentage then
      text = text .. string.format(" %d%%", progress.percentage)
    end
    
    return text
  end
end

return M