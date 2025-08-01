-- Test the new file-based MCP communication
vim.notify("Testing file-based MCP communication...", vim.log.levels.INFO)

-- Create a test diff request
local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")
local diff_dir = data_dir .. "/claucode/diffs"
vim.fn.mkdir(diff_dir, "p")

local test_hash = "test123"
local test_request = {
  hash = test_hash,
  filepath = "/tmp/test.txt",
  original = "Hello World",
  modified = "Hello Neovim!",
  timestamp = os.time()
}

-- Write test request
local request_file = diff_dir .. "/" .. test_hash .. ".request.json"
vim.fn.writefile({vim.fn.json_encode(test_request)}, request_file)

vim.notify("Test request written to: " .. request_file, vim.log.levels.INFO)

-- The diff watcher should pick this up and show the diff window