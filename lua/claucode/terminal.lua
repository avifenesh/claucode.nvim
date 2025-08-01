local M = {}

local terminal_buf = nil
local terminal_win = nil
local terminal_job_id = nil

function M.open_claude_terminal(cli_args)
  local config = require("claucode").get_config()
  
  -- Check if terminal already exists and is valid
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    -- Focus the existing terminal
    vim.api.nvim_set_current_win(terminal_win)
    return
  end
  
  -- Save current window
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create a horizontal split at the bottom
  vim.cmd('botright split')
  local height_ratio = (config.ui and config.ui.terminal and config.ui.terminal.height) or 0.5
  local height = math.floor(vim.o.lines * height_ratio)
  vim.cmd('resize ' .. height)
  
  -- Create or reuse terminal buffer
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    -- Reuse existing buffer
    vim.api.nvim_set_current_buf(terminal_buf)
    terminal_win = vim.api.nvim_get_current_win()
  else
    -- Create new terminal buffer
    terminal_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(terminal_buf)
    terminal_win = vim.api.nvim_get_current_win()
    
    -- Build command with optional CLI arguments
    local command = config.command
    
    -- Check if user provided their own permission mode or MCP config
    local has_permission_mode = cli_args and cli_args:match("%-%-permission%-mode")
    local has_mcp_config = cli_args and cli_args:match("%-%-mcp%-config")
    
    -- Add MCP config if available and not already specified
    local mcp = require("claucode.mcp")
    local mcp_config_file = mcp.get_mcp_config_file and mcp.get_mcp_config_file()
    if mcp_config_file and config.mcp and config.mcp.enabled and not has_mcp_config then
      command = command .. " --mcp-config " .. mcp_config_file
      vim.notify("Claude Terminal: Using MCP server for diff preview", vim.log.levels.INFO)
    elseif config.bridge and config.bridge.show_diff then
      -- Warn if diff preview is enabled without MCP
      vim.notify("Claude Terminal: Diff preview requires MCP server. Enable MCP or disable show_diff.", vim.log.levels.WARN)
    end
    
    if cli_args and cli_args ~= "" then
      command = command .. " " .. cli_args
    end
    
    -- Start Claude in the terminal
    terminal_job_id = vim.fn.termopen(command, {
      cwd = vim.fn.getcwd(),
      on_exit = function(job_id, exit_code, event_type)
        -- Clean up when terminal closes
        terminal_job_id = nil
      end
    })
    
    -- Enable vim mode after Claude starts
    vim.defer_fn(function()
      if terminal_job_id then
        -- Send /vim command to enable vim mode
        vim.api.nvim_chan_send(terminal_job_id, "/vim\n")
      end
    end, 1000)
    
    -- Set buffer name
    vim.api.nvim_buf_set_name(terminal_buf, 'Claude Terminal')
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(terminal_buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(terminal_buf, 'bufhidden', 'hide')
  end
  
  -- Set window options
  vim.api.nvim_win_set_option(terminal_win, 'number', false)
  vim.api.nvim_win_set_option(terminal_win, 'relativenumber', false)
  vim.api.nvim_win_set_option(terminal_win, 'signcolumn', 'no')
  
  -- Enter insert mode
  vim.cmd('startinsert')
  
  -- Add keymaps for the terminal buffer
  local opts = { noremap = true, silent = true, buffer = terminal_buf }
  -- Allow Ctrl+W to switch windows in terminal mode
  vim.keymap.set('t', '<C-w>', '<C-\\><C-n><C-w>', opts)
  -- Quick close with leader+q
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
  
  -- Send text to terminal
  vim.api.nvim_chan_send(terminal_job_id, text .. "\n")
  
  -- Focus terminal window
  if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
    vim.api.nvim_set_current_win(terminal_win)
  end
end

function M.send_current_selection_to_terminal()
  -- Get visual selection
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
    -- Adjust for character-wise selection
    if mode == "v" then
      lines[1] = lines[1]:sub(start_pos[3])
      if #lines > 1 then
        lines[#lines] = lines[#lines]:sub(1, end_pos[3])
      else
        lines[1] = lines[1]:sub(1, end_pos[3] - start_pos[3] + 1)
      end
    end
    
    local selection = table.concat(lines, "\n")
    
    -- Open terminal if not already open
    if not (terminal_win and vim.api.nvim_win_is_valid(terminal_win)) then
      M.open_claude_terminal()
      -- Wait a bit for terminal to initialize
      vim.defer_fn(function()
        M.send_to_terminal(selection)
      end, 500)
    else
      M.send_to_terminal(selection)
    end
  end
end

return M