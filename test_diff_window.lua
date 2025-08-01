-- Test diff window directly
-- Run this with :luafile % in Neovim

local mcp = require("claucode.mcp")

-- Start the diff watcher if not running
if not mcp.diff_watcher_timer then
  mcp.start_diff_watcher()
  vim.notify("Started diff watcher", vim.log.levels.INFO)
end

-- Create a test diff window after a short delay
vim.defer_fn(function()
  vim.notify("Opening test diff window...", vim.log.levels.INFO)
  mcp.show_diff_window(
    "test_" .. os.time(),
    "/tmp/test_file.txt",
    "Original content\nLine 2\nLine 3",
    "Modified content!\nLine 2 changed\nLine 3\nLine 4 added"
  )
end, 500)