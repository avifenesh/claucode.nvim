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

local function hello(name)
  name = name or "world"
  print("Hello, " .. name .. "!")
end

local function calculate_sum(a, b)
  -- Add validation
  if type(a) ~= "number" or type(b) ~= "number" then
    error("Both arguments must be numbers")
  end
  return a + b
end

local function calculate_product(a, b)
  -- New function for testing diff
  return a * b
end

-- Test the functions
hello()
hello("Neovim")
print("Sum of 5 and 3 is:", calculate_sum(5, 3))
print("Product of 4 and 7 is:", calculate_product(4, 7))