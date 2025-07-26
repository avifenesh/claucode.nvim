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

local function find_claude_command()
  -- First check if 'claude' is in PATH
  if vim.fn.executable("claude") == 1 then
    return "claude"
  end
  
  -- Check common installation paths
  local common_paths = {
    vim.fn.expand("~/.claude/local/claude"),
    vim.fn.expand("~/node_modules/.bin/claude"),
    "/usr/local/bin/claude",
    "/opt/homebrew/bin/claude",
  }
  
  for _, path in ipairs(common_paths) do
    -- Check if file exists and is readable
    if vim.fn.filereadable(path) == 1 then
      -- Test if we can actually run it
      local handle = io.popen(path .. " --version 2>&1")
      if handle then
        local result = handle:read("*a")
        handle:close()
        if result:match("Claude Code") then
          return path
        end
      end
    end
  end
  
  return "claude" -- fallback
end

local function merge_config(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
  
  -- Auto-detect claude command if not specified
  if M.config.command == "claude" and vim.fn.executable("claude") == 0 then
    local detected = find_claude_command()
    if detected ~= "claude" then
      M.config.command = detected
      vim.notify("Claude Code CLI found at: " .. detected, vim.log.levels.INFO)
    end
  end
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