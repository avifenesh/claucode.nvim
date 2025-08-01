-- Test the fixed Claude command
vim.notify("Testing fixed Claude command...", vim.log.levels.INFO)

-- Simple test through the command
vim.defer_fn(function()
  vim.cmd("Claude say hello")
end, 500)