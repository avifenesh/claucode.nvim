local M = {}

local defaults = {
  command = 'claude',
  model = 'sonnet',
  auto_start = false,
  max_retries = 3,
  retry_delay = 1000, -- milliseconds
  timeout = 30000, -- milliseconds
  
  keymaps = {
    enable = true,
    complete = '<leader>cc',
    edit = '<leader>ce', 
    chat = '<leader>ct',
    accept = '<Tab>',
    dismiss = '<Esc>',
  },
  
  ui = {
    chat = {
      width = 0.8,
      height = 0.8,
      border = 'rounded',
      title = 'Claude Code Chat',
      title_pos = 'center',
    },
    inline = {
      enabled = true,
      highlight = 'Comment',
      priority = 200,
    },
    progress = {
      enabled = true,
      spinner = 'default', -- default, dots, circle, square, moon
      notify = false,
    },
    diff_preview = {
      enabled = true,
      auto_show = true,
      keymaps = {
        accept = '<CR>',
        reject = '<Esc>',
        accept_line = 'a',
        reject_line = 'r',
        next_hunk = ']h',
        prev_hunk = '[h',
      },
    },
  },
  
  context = {
    include_buffers = true,
    include_project = true,
    max_lines = 1000,
    smart_context = true,
  },
  
  integrations = {
    cmp = {
      enabled = true,
      priority = 80,
      multiline = true,
    },
    telescope = {
      enabled = true,
    },
    lsp = {
      enabled = true,
      code_actions = true,
      hover = true,
    },
    git = {
      enabled = true,
    },
    neo_tree = {
      enabled = true,
    },
    trouble = {
      enabled = true,
    },
    dap = {
      enabled = true,
    },
    which_key = {
      enabled = true,
    },
    lualine = {
      enabled = true,
    },
    noice = {
      enabled = true,
    },
  },
  
  performance = {
    debounce_ms = 300,
    cache = {
      enabled = true,
      ttl = 900000, -- 15 minutes
    },
  },
  
  templates = {}, -- User-defined templates
  
  log_level = vim.log.levels.INFO,
  cache_dir = vim.fn.stdpath('cache') .. '/claude-code',
}

function M.get()
  return vim.tbl_deep_extend('force', defaults, _G.ClaudeCodeConfig or {})
end

function M.set(opts)
  _G.ClaudeCodeConfig = vim.tbl_deep_extend('force', M.get(), opts or {})
  return _G.ClaudeCodeConfig
end

function M.validate()
  local config = M.get()
  
  -- Validate command exists
  if vim.fn.executable(config.command) == 0 then
    return false, string.format("Command '%s' not found. Please install Claude Code CLI.", config.command)
  end
  
  -- Validate model
  local valid_models = {'sonnet', 'opus', 'haiku'}
  if not vim.tbl_contains(valid_models, config.model) then
    return false, string.format("Invalid model '%s'. Valid models: %s", config.model, table.concat(valid_models, ', '))
  end
  
  -- Create cache directory if needed
  vim.fn.mkdir(config.cache_dir, 'p')
  
  return true
end

return M