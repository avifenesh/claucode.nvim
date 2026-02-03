local M = {}

local terminal_buf = nil
local terminal_win = nil
local terminal_job_id = nil

function M.open_claude_terminal(cli_args)
  local config = require("claucode").get_config()
  
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    vim.api.nvim_set_current_win(terminal_win)
    return
  end
  
  local current_win = vim.api.nvim_get_current_win()
  
  vim.cmd('botright split')
  local height_ratio = (config.ui and config.ui.terminal and config.ui.terminal.height) or 0.5
  local height = math.floor(vim.o.lines * height_ratio)
  vim.cmd('resize ' .. height)
  
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    vim.api.nvim_set_current_buf(terminal_buf)
    terminal_win = vim.api.nvim_get_current_win()
  else
    terminal_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(terminal_buf)
    terminal_win = vim.api.nvim_get_current_win()
    
    -- Build command as array to prevent injection
    local cmd_args = {config.command}
    
    -- Parse cli_args safely if provided
    if cli_args and cli_args ~= "" then
      -- Robust tokenization that handles quoted strings
      local i = 1
      local len = #cli_args
      while i <= len do
        -- Skip whitespace
        while i <= len and cli_args:sub(i, i):match("%s") do
          i = i + 1
        end
        if i > len then break end
        
        local char = cli_args:sub(i, i)
        local arg = ""
        
        if char == '"' or char == "'" then
          -- Quoted argument: find matching closing quote
          local quote = char
          i = i + 1
          local start = i
          while i <= len and cli_args:sub(i, i) ~= quote do
            i = i + 1
          end
          arg = cli_args:sub(start, i - 1)
          i = i + 1 -- skip closing quote
        else
          -- Unquoted argument: read until whitespace
          local start = i
          while i <= len and not cli_args:sub(i, i):match("%s") do
            i = i + 1
          end
          arg = cli_args:sub(start, i - 1)
        end
        
        if arg ~= "" then
          table.insert(cmd_args, arg)
        end
      end
    end
    
    terminal_job_id = vim.fn.termopen(cmd_args, {
      cwd = vim.fn.getcwd(),
      on_exit = function(job_id, exit_code, event_type)
        terminal_job_id = nil
      end
    })
    
    vim.defer_fn(function()
      if terminal_job_id then
        vim.api.nvim_chan_send(terminal_job_id, "/vim\n")
      end
    end, 1000)
    
    vim.api.nvim_buf_set_name(terminal_buf, 'Claude Terminal')
    
    vim.bo[terminal_buf].buflisted = false
    vim.bo[terminal_buf].bufhidden = 'hide'
  end
  
  vim.wo[terminal_win].number = false
  vim.wo[terminal_win].relativenumber = false
  vim.wo[terminal_win].signcolumn = 'no'
  
  vim.cmd('startinsert')
  
  local opts = { noremap = true, silent = true, buffer = terminal_buf }
  vim.keymap.set('t', '<C-w>', '<C-\\><C-n><C-w>', opts)
  vim.keymap.set('t', '<leader>q', '<C-\\><C-n>:close<CR>', opts)
  vim.keymap.set('n', '<leader>q', ':close<CR>', opts)
end

function M.close_claude_terminal()
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    vim.api.nvim_win_close(terminal_win, false)
    terminal_win = nil
  end
end

function M.toggle_claude_terminal()
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    M.close_claude_terminal()
  else
    M.open_claude_terminal()
  end
end

function M.send_to_terminal(text)
  if not terminal_job_id then
    vim.notify("Claude terminal is not running", vim.log.levels.WARN)
    return
  end
  
  vim.api.nvim_chan_send(terminal_job_id, text .. "\n")
  
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    vim.api.nvim_set_current_win(terminal_win)
  end
end

function M.send_current_selection_to_terminal()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(
    0,
    start_pos[2] - 1,
    end_pos[2],
    false
  )
  
  if #lines > 0 then
    local mode = vim.fn.visualmode()
    if mode == "v" then
      lines[1] = lines[1]:sub(start_pos[3])
      if #lines > 1 then
        lines[#lines] = lines[#lines]:sub(1, end_pos[3])
      else
        lines[1] = lines[1]:sub(1, end_pos[3] - start_pos[3] + 1)
      end
    end
    
    local selection = table.concat(lines, "\n")
    
    if not (terminal_win and vim.api.nvim_win_is_valid(terminal_win)) then
      M.open_claude_terminal()
      vim.defer_fn(function()
        M.send_to_terminal(selection)
      end, 500)
    else
      M.send_to_terminal(selection)
    end
  end
end

return M