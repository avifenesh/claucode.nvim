-- Simple test file for diff preview
local function test()
  print("Hello from test")
end

local function greet(name)
  print("Hello, " .. (name or "World") .. "!")
end

test()
greet("Neovim")