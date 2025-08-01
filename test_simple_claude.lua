-- Simple test for Claude command
local config = require("claucode").get_config()

vim.notify("=== Simple Claude Test ===", vim.log.levels.INFO)
vim.notify("Command: " .. config.command, vim.log.levels.INFO)

-- Test 1: Basic command without arguments
local output1 = vim.fn.system(config.command .. " --version")
vim.notify("Version test: " .. (output1 or "nil"), vim.log.levels.INFO)

-- Test 2: Basic prompt (correct syntax)
local output2 = vim.fn.system(config.command .. " -p 'say hello'")
vim.notify("Basic prompt test exit code: " .. vim.v.shell_error, vim.log.levels.INFO)
if vim.v.shell_error ~= 0 then
  vim.notify("Output: " .. (output2 or "nil"), vim.log.levels.ERROR)
else
  vim.notify("Success! Output length: " .. #output2, vim.log.levels.INFO)
end

-- Test 3: With permission mode (correct syntax)
local output3 = vim.fn.system(config.command .. " -p --permission-mode acceptEdits 'say hello'")
vim.notify("With permission mode exit code: " .. vim.v.shell_error, vim.log.levels.INFO)
if vim.v.shell_error ~= 0 then
  vim.notify("Output: " .. (output3 or "nil"), vim.log.levels.ERROR)
else
  vim.notify("Success! Output length: " .. #output3, vim.log.levels.INFO)
end

-- Test our actual command through bridge
vim.defer_fn(function()
  vim.cmd("Claude say hello")
end, 500)