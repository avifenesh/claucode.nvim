# MCP Diff Preview Guide

## How It Works

The Claucode MCP diff preview uses file-based communication between Claude and Neovim:

1. When Claude uses `nvim_edit_with_diff` or `nvim_write_with_diff` tools, it writes a diff request to `~/.local/share/claucode/diffs/`
2. Any Neovim instance with the diff watcher running will detect and display the diff
3. Your response (accept/reject) is written back as a file for Claude to read

## Managing Multiple Neovim Instances

Since the diff preview uses file-based communication, if you have multiple Neovim instances open, the diff might appear in any instance that has the watcher running.

### Best Practices:

1. **Use `:ClaudeDiffToggle`** to control the diff preview feature
2. **Only run the watcher in one instance** to avoid confusion

### Commands:

- `:ClaudeDiffToggle` - Toggle diff preview on/off (manages watcher and CLAUDE.md automatically)

### In the Diff Window:

- Press `a` to accept changes
- Press `r` to reject changes
- Press `q` or `<Esc>` to cancel (same as reject)

### Troubleshooting:

1. **Diff appears in wrong window**: Stop the watcher in other instances with `:ClaudeDiffToggle`
2. **Keys don't work**: Make sure the diff window is focused and you're in normal mode
3. **No diff appears**: Check `:ClaudeDiffStatus` and start watcher if needed

## Configuration

In your Neovim config:

```lua
require("claucode").setup({
  bridge = {
    show_diff = true,  -- Enable diff preview
  },
  mcp = {
    enabled = true,    -- Enable MCP server
  },
})
```