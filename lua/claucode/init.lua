-- claucode.nvim - Bridge between Neovim and Claude Code CLI
-- Repository: https://github.com/your-username/claucode.nvim
-- License: MIT

local M = {}

-- Default configuration
M.config = {
  -- Claude Code CLI command
  command = "claude",
  -- Default model to use
  model = "claude-3-5-sonnet-20241022",
  -- Auto-start file watcher on setup
  auto_start_watcher = true,
  -- Enable default keymaps
  keymaps = {
    enable = true,
    prefix = "<leader>ai",  -- AI prefix to avoid conflicts
  },
  -- File watcher settings
  watcher = {
    -- Debounce time in milliseconds
    debounce = 100,
    -- Ignore patterns
    ignore_patterns = { "%.git/", "node_modules/", "%.swp$", "%.swo$" },
  },
  -- Bridge settings
  bridge = {
    -- Timeout for CLI commands in milliseconds
    timeout = 30000,
    -- Max output buffer size
    max_output = 1048576, -- 1MB
  },
  -- UI settings
  ui = {
    -- Diff preview window settings
    diff = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  },
}

local function merge_config(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

function M.setup(user_config)
  merge_config(user_config)
  
  -- Load modules
  require("claucode.commands").setup(M.config)
  
  if M.config.keymaps.enable then
    require("claucode.keymaps").setup(M.config)
  end
  
  if M.config.auto_start_watcher then
    require("claucode.watcher").start(M.config)
  end
  
  -- Create user commands
  vim.api.nvim_create_user_command("Claude", function(opts)
    require("claucode.commands").claude(opts.args)
  end, {
    nargs = "*",
    desc = "Send a prompt to Claude Code CLI",
  })
  
  vim.api.nvim_create_user_command("ClaudeStop", function()
    require("claucode.bridge").stop()
    require("claucode.watcher").stop()
  end, {
    desc = "Stop Claude Code bridge and file watcher",
  })
  
  vim.api.nvim_create_user_command("ClaudeStart", function()
    require("claucode.watcher").start(M.config)
  end, {
    desc = "Start Claude Code file watcher",
  })
  
  vim.api.nvim_create_user_command("ClaudeReview", function()
    require("claucode.review").show_pending_changes()
  end, {
    desc = "Review pending changes from Claude",
  })
end

function M.get_config()
  return M.config
end

return M