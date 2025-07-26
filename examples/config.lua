-- Example configuration for claude-code.nvim
-- Copy this to your Neovim config and adjust as needed

require('claude-code').setup({
  -- Bridge configuration
  bridge = {
    method = 'file',  -- Communication method ('file' or 'mcp' in future)
    shared_dir = vim.fn.stdpath('cache') .. '/claude-code',
  },
  
  -- File watching
  watcher = {
    enabled = true,      -- Watch for file changes
    auto_reload = true,  -- Auto-reload when Claude changes files
    diff_preview = true, -- Show diff preview for changes
  },
  
  -- Quick prompts
  prompts = {
    fix = "Fix the issues in this code",
    explain = "Explain what this code does",
    improve = "Improve this code",
    test = "Write tests for this code",
    document = "Add documentation to this code",
    refactor = "Refactor this code for better readability",
    optimize = "Optimize this code for performance",
  },
  
  -- UI settings
  ui = {
    diff = {
      position = 'right',  -- Split position for diff view
      width = 0.5,         -- Width of diff split (0-1)
    },
    notifications = true,  -- Show notifications
  },
  
  -- Keymaps (using <leader>c prefix for all Claude commands)
  keymaps = {
    quick_prompt = '<leader>cc',     -- Send prompt to Claude
    share_context = '<leader>cx',    -- Share context (x for conteXt)
    review_changes = '<leader>cd',   -- Review diff (d for diff)
    -- Optional quick action mappings (uncomment if desired)
    -- quick_fix = '<leader>cf',        -- Quick fix command
    -- quick_explain = '<leader>ce',    -- Quick explain command
    -- quick_improve = '<leader>ci',    -- Quick improve command
    -- quick_test = '<leader>ct',       -- Quick test command
    -- quick_document = '<leader>cn',   -- Quick document command (n for notes)
  },
})

-- Example: Add custom prompt
vim.api.nvim_create_user_command('ClaudeSecurityReview', function()
  require('claude-code').prompt('Review this code for security vulnerabilities')
end, {
  desc = 'Ask Claude to review code for security issues',
})

-- Example: Integration with Telescope
-- Requires telescope.nvim
local has_telescope, telescope = pcall(require, 'telescope')
if has_telescope then
  telescope.load_extension('claude_code')
  -- Now you can use :Telescope claude_code prompts
end