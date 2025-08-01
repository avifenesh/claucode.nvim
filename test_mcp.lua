-- Test script for MCP integration
-- Run this with :luafile test_mcp.lua

-- Test showing a diff
local mcp = require('claucode.mcp')

-- Simulate a diff preview
mcp.show_diff_window("test123", "/tmp/test.txt", 
  "Hello World\nThis is a test file\n",
  "Hello World!\nThis is a modified test file\nWith a new line\n"
)

print("MCP diff preview test shown. Press 'a' to accept, 'r' to reject")