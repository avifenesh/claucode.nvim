local M = {}

local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.setup(config)
  local prefix = config.keymaps.prefix or "<leader>c"
  
  -- Normal mode mappings
  map("n", prefix .. "c", ":Claude ", {
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
  
  -- Terminal mappings
  map("n", prefix .. "o", "<cmd>ClaudeTerminal<CR>", {
    desc = "Open Claude terminal",
  })
  
  map("n", prefix .. "T", "<cmd>ClaudeTerminalToggle<CR>", {
    desc = "Toggle Claude terminal",
  })
  
  -- Visual mode mappings
  map("v", prefix .. "c", ":<C-u>lua require('claucode.commands').store_visual_selection()<CR>:Claude ", {
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
  
  map("v", prefix .. "T", ":<C-u>lua require('claucode.terminal').send_current_selection_to_terminal()<CR>", {
    desc = "Send selection to Claude terminal",
  })
  
  -- Which-key integration (if available)
  local ok, which_key = pcall(require, "which-key")
  if ok then
    -- Try which-key v3 format first (add method)
    if which_key.add then
      which_key.add({
        { prefix, group = "Claude Code" },
        { prefix .. "c", desc = "Prompt", mode = "n" },
        { prefix .. "f", desc = "Review File", mode = "n" },
        { prefix .. "e", desc = "Explain", mode = "n" },
        { prefix .. "x", desc = "Fix", mode = "n" },
        { prefix .. "t", desc = "Generate Tests", mode = "n" },
        { prefix .. "r", desc = "Review Changes", mode = "n" },
        { prefix .. "s", desc = "Stop", mode = "n" },
        { prefix .. "S", desc = "Start Watcher", mode = "n" },
        { prefix .. "a", desc = "Complete at Cursor", mode = "n" },
        
        { prefix, group = "Claude Code", mode = "v" },
        { prefix .. "c", desc = "Prompt with Selection", mode = "v" },
        { prefix .. "e", desc = "Explain Selection", mode = "v" },
        { prefix .. "x", desc = "Fix Selection", mode = "v" },
        { prefix .. "t", desc = "Test Selection", mode = "v" },
      })
    else
      -- Fall back to which-key v2 format (register method)
      which_key.register({
        [prefix] = {
          name = "Claude Code",
          c = { ":Claude ", "Prompt" },
          f = { "<cmd>lua require('claucode.commands').claude_file()<CR>", "Review File" },
          e = { "<cmd>lua require('claucode.commands').claude_explain()<CR>", "Explain" },
          x = { "<cmd>lua require('claucode.commands').claude_fix()<CR>", "Fix" },
          t = { "<cmd>lua require('claucode.commands').claude_test()<CR>", "Generate Tests" },
          r = { "<cmd>ClaudeReview<CR>", "Review Changes" },
          s = { "<cmd>ClaudeStop<CR>", "Stop" },
          S = { "<cmd>ClaudeStart<CR>", "Start Watcher" },
          a = { "<cmd>lua require('claucode.commands').claude_complete()<CR>", "Complete at Cursor" },
        }
      }, { mode = "n" })
      
      which_key.register({
        [prefix] = {
          name = "Claude Code",
          c = { ":<C-u>Claude ", "Prompt with Selection" },
          e = { ":<C-u>lua require('claucode.commands').claude_explain()<CR>", "Explain Selection" },
          x = { ":<C-u>lua require('claucode.commands').claude_fix()<CR>", "Fix Selection" },
          t = { ":<C-u>lua require('claucode.commands').claude_test()<CR>", "Test Selection" },
        }
      }, { mode = "v" })
    end
  end
end

return M