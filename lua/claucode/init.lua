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
    ignore_patterns = {
      "%.git/", "node_modules/", "%.swp$", "%.swo$",
      -- Binary files
      "%.class$", "%.jar$", "%.war$", "%.ear$",  -- Java
      "%.pyc$", "%.pyo$", "%.pyd$",              -- Python
      "%.exe$", "%.dll$", "%.so$", "%.dylib$",   -- Executables/Libraries
      "%.o$", "%.a$", "%.lib$",                  -- Object files
      "%.pdf$", "%.jpg$", "%.jpeg$", "%.png$",   -- Media files
      "%.gif$", "%.bmp$", "%.ico$", "%.webp$",
      "%.mp3$", "%.mp4$", "%.avi$", "%.mov$",
      "%.zip$", "%.tar$", "%.gz$", "%.rar$",     -- Archives
      "%.db$", "%.sqlite$", "%.sqlite3$",        -- Databases
    },
  },
  -- Bridge settings
  bridge = {
    -- Timeout for CLI commands in milliseconds
    timeout = 30000,
    -- Max output buffer size
    max_output = 1048576, -- 1MB
    -- Show diff before applying changes (requires MCP)
    show_diff = false,
  },
  -- MCP settings
  mcp = {
    -- Enable MCP server for diff preview
    enabled = true,
    -- Auto-build MCP server if not found
    auto_build = true,
  },
  -- UI settings
  ui = {
    -- Diff preview window settings
    diff = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
    -- Terminal settings
    terminal = {
      height = 0.5, -- 50% of screen height (increased from 30%)
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
  
  -- Validate configuration
  if M.config.bridge.show_diff and not M.config.mcp.enabled then
    vim.notify("Claucode: show_diff requires MCP to be enabled. Disabling show_diff.", vim.log.levels.WARN)
    M.config.bridge.show_diff = false
  end
  
  -- Load modules
  require("claucode.commands").setup(M.config)
  
  if M.config.keymaps.enable then
    require("claucode.keymaps").setup(M.config)
  end
  
  if M.config.auto_start_watcher then
    require("claucode.watcher").start(M.config)
  end
  
  -- Setup MCP integration if enabled
  if M.config.mcp.enabled then
    require("claucode.mcp").setup(M.config)
  end
  
  -- Setup CLAUDE.md management for diff preview
  if M.config.mcp.enabled and M.config.bridge.show_diff then
    require("claucode.claude_md").setup()
  end
  
  -- Create user commands
  vim.api.nvim_create_user_command("Claude", function(opts)
    -- Check if called from visual mode
    local from_visual = opts.range > 0
    if from_visual then
      require("claucode.commands").store_visual_selection()
    end
    require("claucode.commands").claude(opts.args, from_visual)
  end, {
    nargs = "*",
    range = true,
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
  
  vim.api.nvim_create_user_command("ClaudeTerminal", function(opts)
    require("claucode.terminal").open_claude_terminal(opts.args)
  end, {
    nargs = "*",
    desc = "Open Claude in a terminal split with optional CLI parameters",
  })
  
  vim.api.nvim_create_user_command("ClaudeTerminalToggle", function()
    require("claucode.terminal").toggle_claude_terminal()
  end, {
    desc = "Toggle Claude terminal",
  })
  
  vim.api.nvim_create_user_command("ClaudeTerminalSend", function(opts)
    require("claucode.terminal").send_to_terminal(opts.args)
  end, {
    nargs = "+",
    desc = "Send text to Claude terminal",
  })
  
  vim.api.nvim_create_user_command("ClaudeDiffInstructions", function()
    require("claucode.claude_md").toggle_diff_instructions()
  end, {
    desc = "Toggle Neovim diff preview instructions in CLAUDE.md",
  })
end

function M.get_config()
  return M.config
end

return M