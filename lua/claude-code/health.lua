local M = {}
local health = vim.health or require('health')
local config = require('claude-code.config')
local process = require('claude-code.process')

function M.check()
  health.start('Claude Code')
  
  -- Check Neovim version
  if vim.fn.has('nvim-0.5.0') == 1 then
    health.ok('Neovim version: ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch)
  else
    health.error('Neovim 0.5.0+ required')
  end
  
  -- Check Claude Code CLI
  local claude_cmd = config.get().command
  if vim.fn.executable(claude_cmd) == 1 then
    health.ok('Claude Code CLI found: ' .. claude_cmd)
    
    -- Try to get version
    local version = vim.fn.system(claude_cmd .. ' --version')
    if vim.v.shell_error == 0 then
      health.info('Claude Code version: ' .. vim.trim(version))
    end
  else
    health.error('Claude Code CLI not found', {
      'Install with: npm install -g @anthropic-ai/claude-code',
      'Or set custom command in config',
    })
  end
  
  -- Check authentication
  local auth_status = vim.fn.system(claude_cmd .. ' auth status 2>&1')
  if vim.v.shell_error == 0 and auth_status:match('Authenticated') then
    health.ok('Claude Code authenticated')
  else
    health.warn('Claude Code not authenticated', {
      'Run: claude auth login',
      'Or set ANTHROPIC_API_KEY environment variable',
    })
  end
  
  -- Check process status
  if process.is_running() then
    health.ok('Claude Code process is running')
  else
    health.info('Claude Code process not running (start with :ClaudeCode start)')
  end
  
  -- Check configuration
  local ok, err = config.validate()
  if ok then
    health.ok('Configuration valid')
  else
    health.error('Configuration error: ' .. err)
  end
  
  -- Check cache directory
  local cache_dir = config.get().cache_dir
  if vim.fn.isdirectory(cache_dir) == 1 then
    health.ok('Cache directory exists: ' .. cache_dir)
  else
    health.warn('Cache directory does not exist: ' .. cache_dir)
  end
  
  -- Check for common issues
  health.start('Common Issues')
  
  -- Check if curl is available (for API calls)
  if vim.fn.executable('curl') == 1 then
    health.ok('curl is available')
  else
    health.warn('curl not found (may affect some features)')
  end
  
  -- Check Node.js
  if vim.fn.executable('node') == 1 then
    local node_version = vim.fn.system('node --version')
    health.ok('Node.js found: ' .. vim.trim(node_version))
  else
    health.error('Node.js not found (required for Claude Code CLI)')
  end
  
  -- Check integrations
  health.start('Plugin Integrations')
  local integrations = require('claude-code.integrations').status()
  
  for name, status in pairs(integrations) do
    if status.available then
      if status.enabled then
        health.ok(name .. ' integration available and enabled')
      else
        health.info(name .. ' integration available but disabled')
      end
    else
      health.info(name .. ' integration not available')
    end
  end
  
  -- Check optional dependencies
  health.start('Optional Dependencies')
  
  -- Treesitter
  if pcall(require, 'nvim-treesitter') then
    health.ok('nvim-treesitter found (better context understanding)')
  else
    health.info('nvim-treesitter not found (optional, improves context)')
  end
  
  -- Git
  if vim.fn.executable('git') == 1 then
    health.ok('git found')
  else
    health.warn('git not found (required for git features)')
  end
end

return M