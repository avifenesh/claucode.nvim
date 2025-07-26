-- Commands for Claude Code bridge
local M = {}

function M.setup(config)
  -- Main Claude command for quick prompts
  vim.api.nvim_create_user_command('Claude', function(opts)
    local prompt = opts.args
    if prompt == '' then
      vim.ui.input({
        prompt = 'Claude> ',
      }, function(input)
        if input and input ~= '' then
          require('claude-code.bridge').send_prompt(input)
        end
      end)
    else
      require('claude-code.bridge').send_prompt(prompt)
    end
  end, {
    nargs = '*',
    desc = 'Send a prompt to Claude Code CLI',
  })
  
  -- Share context command
  vim.api.nvim_create_user_command('ClaudeContext', function(opts)
    local target = opts.args
    
    if target == 'selection' or target == 'visual' then
      -- Share visual selection
      local start_pos = vim.fn.getpos("'<")
      local end_pos = vim.fn.getpos("'>")
      local lines = vim.api.nvim_buf_get_lines(0, start_pos[2]-1, end_pos[2], false)
      
      local context = {
        type = 'selection',
        content = table.concat(lines, '\n'),
        file = vim.api.nvim_buf_get_name(0),
        range = {
          start = start_pos[2],
          ['end'] = end_pos[2],
        }
      }
      
      require('claude-code.bridge').share_selection(context)
    else
      -- Share current buffer/file
      require('claude-code.bridge').share_current_context()
    end
  end, {
    nargs = '?',
    complete = function()
      return { 'selection', 'visual', 'buffer', 'file' }
    end,
    desc = 'Share current context with Claude Code',
  })
  
  -- Review changes command
  vim.api.nvim_create_user_command('ClaudeReview', function()
    require('claude-code.review').show()
  end, {
    desc = 'Review pending changes from Claude Code',
  })
  
  -- Quick action commands
  for action, prompt in pairs(config.prompts or {}) do
    local cmd_name = 'Claude' .. action:sub(1,1):upper() .. action:sub(2)
    vim.api.nvim_create_user_command(cmd_name, function()
      -- Include current context with the prompt
      local context = require('claude-code.bridge')._gather_context()
      local full_prompt = prompt
      
      if context.selection then
        full_prompt = prompt .. " for this code:\n" .. context.selection.text
      else
        full_prompt = prompt .. " at line " .. context.cursor[1]
      end
      
      require('claude-code.bridge').send_prompt(full_prompt)
    end, {
      desc = prompt,
    })
  end
  
  -- Status command
  vim.api.nvim_create_user_command('ClaudeStatus', function()
    local bridge = require('claude-code.bridge')
    local status = bridge._is_claude_connected() and 'Connected' or 'Not connected'
    local shared_dir = config.bridge.shared_dir
    
    local info = {
      'Claude Code Status: ' .. status,
      'Bridge method: ' .. config.bridge.method,
      'Shared directory: ' .. shared_dir,
      'File watcher: ' .. (config.watcher.enabled and 'Enabled' or 'Disabled'),
      'Auto-reload: ' .. (config.watcher.auto_reload and 'On' or 'Off'),
    }
    
    if not bridge._is_claude_connected() then
      table.insert(info, '')
      table.insert(info, 'To connect Claude Code:')
      table.insert(info, '1. Run `claude` in your terminal')
      table.insert(info, '2. Use `/look ' .. shared_dir .. '/prompt.txt` in Claude')
    end
    
    vim.notify(table.concat(info, '\n'), vim.log.levels.INFO)
  end, {
    desc = 'Show Claude Code bridge status',
  })
  
  -- Reload command (for when file watchers miss changes)
  vim.api.nvim_create_user_command('ClaudeReload', function()
    vim.cmd('checktime')
    vim.notify('Reloaded buffers', vim.log.levels.INFO)
  end, {
    desc = 'Manually reload buffers changed by Claude',
  })
  
  -- Stop command
  vim.api.nvim_create_user_command('ClaudeStop', function()
    require('claude-code.watcher').stop_all()
    vim.notify('Stopped Claude Code watchers', vim.log.levels.INFO)
  end, {
    desc = 'Stop Claude Code file watchers',
  })
end

return M