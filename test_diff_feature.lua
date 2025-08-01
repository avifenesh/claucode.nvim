-- Test script for the diff feature
-- To enable the diff feature, add this to your Neovim config:
--
-- require('claucode').setup({
--   bridge = {
--     show_diff = true,  -- Enable diff preview
--   }
-- })
--
-- Then use :Claude command to ask Claude to modify this file
-- Claude will show a diff preview before applying changes

local function hello()
  print("Hello, world!")
end

local function calculate_sum(a, b)
  return a + b
end

-- Test the functions
hello()
print("Sum of 5 and 3 is:", calculate_sum(5, 3))