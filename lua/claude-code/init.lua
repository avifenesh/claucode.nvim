-- Claude Code Neovim Bridge
-- Connects Neovim with Claude Code CLI running in terminal

local M = {}

M.config = {
  -- How to communicate with Claude Code
  bridge = {
    -- Method: 'file' (shared files), 'mcp' (future)
    method = 'file',
    shared_dir = vim.fn.stdpath('cache') .. '/claude-code',
  },
  
  -- File watching
  watcher = {
    enabled = true,
    auto_reload = true,
    diff_preview = true,
  },
  
  -- Quick prompts
  prompts = {
    fix = "Fix the issues in this code",
    explain = "Explain what this code does", 
    improve = "Improve this code",
    test = "Write tests for this code",
    document = "Add documentation",
  },
  
  -- UI
  ui = {
    diff = {
      position = 'right',
      width = 0.5,
    },
    notifications = true,
  },
  
  -- Keymaps
  keymaps = {
    quick_prompt = '<leader>cc',     -- Send prompt to Claude
    share_context = '<leader>cx',    -- Share context (x for conteXt)
    review_changes = '<leader>cd',   -- Review diff (d for diff)
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  
  -- Create shared directory
  vim.fn.mkdir(M.config.bridge.shared_dir, 'p')
  
  -- Setup modules
  require('claude-code.commands').setup(M.config)
  require('claude-code.watcher').setup(M.config)
  require('claude-code.keymaps').setup(M.config.keymaps)
  
  -- Initialize bridge
  require('claude-code.bridge').init(M.config)
end

-- Public API
M.prompt = function(text)
  require('claude-code.bridge').send_prompt(text)
end

M.share_context = function()
  require('claude-code.bridge').share_current_context()
end

M.review_changes = function()
  require('claude-code.review').show()
end

return M