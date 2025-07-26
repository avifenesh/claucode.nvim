std = luajit
codes = true
self = false

globals = {
  "vim",
  "_G",
  "ClaudeCodeConfig",
  "ClaudeCodeHandlers",
}

read_globals = {
  "describe",
  "it",
  "before_each",
  "after_each",
  "pending",
  "assert",
}

exclude_files = {
  ".luacheckrc",
}

ignore = {
  "212", -- Unused argument
  "213", -- Unused loop variable
  "631", -- Line too long
}