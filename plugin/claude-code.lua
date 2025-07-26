-- Claude Code Neovim Bridge plugin initialization

-- Exit early if already loaded
if vim.g.loaded_claude_code then
  return
end
vim.g.loaded_claude_code = true

-- Check Neovim version
if vim.fn.has('nvim-0.7') == 0 then
  vim.notify('claude-code.nvim requires Neovim >= 0.7', vim.log.levels.WARN)
  return
end

-- Default setup with lazy loading
if not vim.g.claude_code_no_default_setup then
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('ClaudeCodeSetup', { clear = true }),
    once = true,
    callback = function()
      -- Only load if not already configured
      if not vim.g.claude_code_configured then
        require('claude-code').setup({})
        vim.g.claude_code_configured = true
      end
    end,
  })
end