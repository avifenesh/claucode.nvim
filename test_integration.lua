-- Test script for Claude Code integration
-- Run this in Neovim: :luafile test_integration.lua

-- Add the plugin to runtime path
vim.opt.runtimepath:append(vim.fn.getcwd())

-- Load and setup the plugin
local claucode = require("claucode")
claucode.setup({
  command = "claude",
  auto_start_watcher = false, -- Disable for testing
})

-- Test 1: Basic command
print("Test 1: Sending basic prompt...")
vim.cmd("Claude What is 2+2?")

-- Give it time to process
vim.defer_fn(function()
  print("\nTest 2: Testing with current file context...")
  -- Create a test file
  vim.cmd("edit test_file.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "local function hello()",
    "  print('Hello, world!')",
    "end"
  })
  
  -- Test with file context
  vim.cmd("Claude --file What does this function do?")
end, 5000)

-- Test 3: File watcher
vim.defer_fn(function()
  print("\nTest 3: Starting file watcher...")
  vim.cmd("ClaudeStart")
  
  -- Simulate external file change
  vim.defer_fn(function()
    local file = io.open("test_file.lua", "w")
    if file then
      file:write("-- Modified by external process\n")
      file:write("local function hello()\n")
      file:write("  print('Hello, Claude!')\n")
      file:write("end\n")
      file:close()
      print("External file modification simulated")
    end
  end, 2000)
end, 10000)