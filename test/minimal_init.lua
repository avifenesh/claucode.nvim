-- Minimal init.lua for running tests
vim.opt.runtimepath:append('.')

-- Add plenary if available
local plenary_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/plenary.nvim'
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:append(plenary_path)
end

-- Set up minimal test environment
vim.cmd([[
  set noswapfile
  set nobackup
  set nowritebackup
  set undolevels=-1
]])