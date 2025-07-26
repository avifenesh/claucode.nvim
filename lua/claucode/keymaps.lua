local M = {}

local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.setup(config)
  local prefix = config.keymaps.prefix or "<leader>c"
  
  -- Normal mode mappings
  map("n", prefix .. "c", "<cmd>Claude ", {
    desc = "Claude prompt",
    silent = false,
  })
  
  map("n", prefix .. "f", "<cmd>lua require('claucode.commands').claude_file()<CR>", {
    desc = "Claude review file",
  })
  
  map("n", prefix .. "e", "<cmd>lua require('claucode.commands').claude_explain()<CR>", {
    desc = "Claude explain",
  })
  
  map("n", prefix .. "x", "<cmd>lua require('claucode.commands').claude_fix()<CR>", {
    desc = "Claude fix",
  })
  
  map("n", prefix .. "t", "<cmd>lua require('claucode.commands').claude_test()<CR>", {
    desc = "Claude generate tests",
  })
  
  map("n", prefix .. "r", "<cmd>ClaudeReview<CR>", {
    desc = "Claude review changes",
  })
  
  map("n", prefix .. "s", "<cmd>ClaudeStop<CR>", {
    desc = "Claude stop",
  })
  
  map("n", prefix .. "S", "<cmd>ClaudeStart<CR>", {
    desc = "Claude start watcher",
  })
  
  map("n", prefix .. "a", "<cmd>lua require('claucode.commands').claude_complete()<CR>", {
    desc = "Claude complete at cursor",
  })
  
  -- Visual mode mappings
  map("v", prefix .. "c", ":<C-u>Claude ", {
    desc = "Claude prompt with selection",
    silent = false,
  })
  
  map("v", prefix .. "e", ":<C-u>lua require('claucode.commands').claude_explain()<CR>", {
    desc = "Claude explain selection",
  })
  
  map("v", prefix .. "x", ":<C-u>lua require('claucode.commands').claude_fix()<CR>", {
    desc = "Claude fix selection",
  })
  
  map("v", prefix .. "t", ":<C-u>lua require('claucode.commands').claude_test()<CR>", {
    desc = "Claude test selection",
  })
  
  -- Which-key integration (if available)
  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.register({
      [prefix] = {
        name = "Claude Code",
        c = { "Prompt" },
        f = { "Review File" },
        e = { "Explain" },
        x = { "Fix" },
        t = { "Generate Tests" },
        r = { "Review Changes" },
        s = { "Stop" },
        S = { "Start Watcher" },
        a = { "Complete at Cursor" },
      }
    }, { mode = "n" })
    
    which_key.register({
      [prefix] = {
        name = "Claude Code",
        c = { "Prompt with Selection" },
        e = { "Explain Selection" },
        x = { "Fix Selection" },
        t = { "Test Selection" },
      }
    }, { mode = "v" })
  end
end

return M