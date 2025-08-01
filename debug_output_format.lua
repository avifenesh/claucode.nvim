-- Debug what output format Claude actually produces
local config = require("claucode").get_config()

-- Test raw output
local handle = io.popen(config.command .. " -p 'say hello' 2>&1")
local output = handle:read("*a")
handle:close()

vim.notify("=== Raw Output ===", vim.log.levels.INFO)
vim.notify("Length: " .. #output, vim.log.levels.INFO)
vim.notify("First 200 chars: " .. output:sub(1, 200), vim.log.levels.INFO)

-- Check if it's JSON
local ok, parsed = pcall(vim.json.decode, output)
if ok then
  vim.notify("Output is valid JSON!", vim.log.levels.INFO)
  vim.notify("JSON structure: " .. vim.inspect(parsed):sub(1, 200), vim.log.levels.INFO)
else
  vim.notify("Output is NOT JSON, it's plain text", vim.log.levels.INFO)
  -- Check for newlines
  local lines = vim.split(output, "\n", { plain = true })
  vim.notify("Number of lines: " .. #lines, vim.log.levels.INFO)
  for i = 1, math.min(5, #lines) do
    vim.notify("Line " .. i .. ": " .. lines[i]:sub(1, 100), vim.log.levels.INFO)
  end
end