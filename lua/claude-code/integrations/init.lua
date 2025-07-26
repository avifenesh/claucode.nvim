-- Integration loader for claude-code.nvim
-- Manages loading and configuration of plugin integrations

local M = {}
local config = require('claude-code.config')

-- Available integrations
M.integrations = {
  cmp = {
    module = 'claude-code.integrations.cmp',
    check = function() return pcall(require, 'cmp') end,
    setup = function(opts) 
      local cmp = require('cmp')
      local source = require('claude-code.integrations.cmp')
      cmp.register_source('claude_code', source)
    end,
  },
  
  telescope = {
    module = 'claude-code.integrations.telescope',
    check = function() return pcall(require, 'telescope') end,
    setup = function(opts)
      local telescope = require('telescope')
      telescope.load_extension('claude_code')
    end,
  },
  
  lsp = {
    module = 'claude-code.integrations.lsp',
    check = function() return true end, -- Always available
    setup = function(opts)
      require('claude-code.integrations.lsp').setup(opts)
    end,
  },
  
  git = {
    module = 'claude-code.integrations.git',
    check = function() 
      return vim.fn.exists(':Git') > 0 or pcall(require, 'neogit')
    end,
    setup = function(opts)
      require('claude-code.integrations.git').setup(opts)
    end,
  },
  
  neo_tree = {
    module = 'claude-code.integrations.neo-tree',
    check = function() return pcall(require, 'neo-tree') end,
    setup = function(opts)
      require('claude-code.integrations.neo-tree').setup(opts)
    end,
  },
  
  trouble = {
    module = 'claude-code.integrations.trouble',
    check = function() return pcall(require, 'trouble') end,
    setup = function(opts)
      require('claude-code.integrations.trouble').setup(opts)
    end,
  },
  
  dap = {
    module = 'claude-code.integrations.dap',
    check = function() return pcall(require, 'dap') end,
    setup = function(opts)
      require('claude-code.integrations.dap').setup(opts)
    end,
  },
  
  which_key = {
    module = 'claude-code.integrations.which-key',
    check = function() return pcall(require, 'which-key') end,
    setup = function(opts)
      require('claude-code.integrations.which-key').setup(opts)
    end,
  },
  
  lualine = {
    module = 'claude-code.integrations.lualine',
    check = function() return pcall(require, 'lualine') end,
    setup = function(opts)
      -- Lualine integration is passive, just provides components
      return true
    end,
  },
  
  noice = {
    module = 'claude-code.integrations.noice',
    check = function() return pcall(require, 'noice') end,
    setup = function(opts)
      require('claude-code.integrations.noice').setup(opts)
    end,
  },
}

-- Load and setup integrations
function M.setup()
  local integration_config = config.get().integrations or {}
  
  for name, integration in pairs(M.integrations) do
    local opts = integration_config[name]
    
    -- Skip if explicitly disabled
    if opts and opts.enabled == false then
      goto continue
    end
    
    -- Check if integration is available
    if integration.check() then
      -- Try to load and setup
      local ok, err = pcall(function()
        if integration.setup then
          integration.setup(opts or {})
        end
      end)
      
      if ok then
        vim.notify(string.format('Claude Code: %s integration loaded', name), vim.log.levels.DEBUG)
      else
        vim.notify(
          string.format('Claude Code: Failed to setup %s integration: %s', name, err),
          vim.log.levels.WARN
        )
      end
    end
    
    ::continue::
  end
end

-- Get status of all integrations
function M.status()
  local status = {}
  
  for name, integration in pairs(M.integrations) do
    status[name] = {
      available = integration.check(),
      enabled = config.get().integrations[name] ~= false,
    }
  end
  
  return status
end

-- Manually load a specific integration
function M.load(name)
  local integration = M.integrations[name]
  if not integration then
    return false, 'Unknown integration: ' .. name
  end
  
  if not integration.check() then
    return false, 'Integration not available: ' .. name
  end
  
  local ok, err = pcall(function()
    if integration.setup then
      integration.setup(config.get().integrations[name] or {})
    end
  end)
  
  return ok, err
end

return M