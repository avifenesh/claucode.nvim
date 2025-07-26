-- Keymaps for Claude Code bridge
local M = {}

function M.setup(keymaps)
  -- Quick prompt
  if keymaps.quick_prompt then
    vim.keymap.set({'n', 'v'}, keymaps.quick_prompt, function()
      local mode = vim.fn.mode()
      if mode == 'v' or mode == 'V' then
        -- Visual mode - send selection with prompt
        vim.cmd('normal! "vy')
        local selection = vim.fn.getreg('v')
        vim.ui.input({
          prompt = 'Claude (with selection)> ',
        }, function(input)
          if input and input ~= '' then
            local prompt = input .. " for this code:\n" .. selection
            require('claude-code.bridge').send_prompt(prompt)
          end
        end)
      else
        -- Normal mode - just prompt
        vim.ui.input({
          prompt = 'Claude> ',
        }, function(input)
          if input and input ~= '' then
            require('claude-code.bridge').send_prompt(input)
          end
        end)
      end
    end, {
      desc = 'Quick prompt to Claude Code',
    })
  end
  
  -- Share context
  if keymaps.share_context then
    vim.keymap.set({'n', 'v'}, keymaps.share_context, function()
      local mode = vim.fn.mode()
      if mode == 'v' or mode == 'V' then
        vim.cmd('ClaudeContext selection')
      else
        vim.cmd('ClaudeContext')
      end
    end, {
      desc = 'Share context with Claude Code',
    })
  end
  
  -- Review changes
  if keymaps.review_changes then
    vim.keymap.set('n', keymaps.review_changes, function()
      require('claude-code.review').show()
    end, {
      desc = 'Review Claude Code changes',
    })
  end
  
  -- Quick actions
  if keymaps.quick_fix then
    vim.keymap.set({'n', 'v'}, keymaps.quick_fix, '<cmd>ClaudeFix<cr>', {
      desc = 'Ask Claude to fix issues',
    })
  end
  
  if keymaps.quick_explain then
    vim.keymap.set({'n', 'v'}, keymaps.quick_explain, '<cmd>ClaudeExplain<cr>', {
      desc = 'Ask Claude to explain code',
    })
  end
  
  if keymaps.quick_improve then
    vim.keymap.set({'n', 'v'}, keymaps.quick_improve, '<cmd>ClaudeImprove<cr>', {
      desc = 'Ask Claude to improve code',
    })
  end
  
  if keymaps.quick_test then
    vim.keymap.set({'n', 'v'}, keymaps.quick_test, '<cmd>ClaudeTest<cr>', {
      desc = 'Ask Claude to write tests',
    })
  end
  
  if keymaps.quick_document then
    vim.keymap.set({'n', 'v'}, keymaps.quick_document, '<cmd>ClaudeDocument<cr>', {
      desc = 'Ask Claude to add documentation',
    })
  end
end

return M