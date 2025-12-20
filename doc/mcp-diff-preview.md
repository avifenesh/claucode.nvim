# MCP Diff Preview Guide

## How It Works

The Claucode MCP diff preview uses session-scoped file-based communication between Claude and Neovim:

1. When Claude uses `nvim_edit_with_diff` or `nvim_write_with_diff` tools, it writes a diff request to a session-specific directory under `~/.local/share/claucode/diffs/<session-id>/`
2. Only the Neovim instance with the matching session ID will detect and display the diff
3. Your response (accept/reject) is written back as a file for Claude to read

## Multi-Session Support

**Good news!** Multiple Neovim instances now work seamlessly without conflicts:

- Each Neovim instance has a unique session ID (generated from PID + timestamp)
- Diff requests are automatically routed to the correct Neovim instance
- MCP server names are session-specific by default (e.g., `claucode-nvim-12345-1234567890-5678`)
- No manual configuration needed for most users

### Managing Multiple Neovim Instances

You can now safely run multiple Neovim instances with diff preview enabled simultaneously. Each instance will only show diffs for its own Claude sessions.

**Best Practices:**

1. **Just use it normally** - Multi-instance support is automatic
2. **Use `:ClaudeDiffToggle`** to enable/disable diff preview per instance
3. **Session isolation** - Diffs from one instance won't interfere with another

### Commands:

- `:ClaudeDiffToggle` - Toggle diff preview on/off (manages watcher and CLAUDE.md automatically)

### In the Diff Window:

- Press `a` to accept changes
- Press `r` to reject changes
- Press `q` or `<Esc>` to cancel (same as reject)
- Press `Tab`, `<C-h>`, or `<C-l>` to switch between windows

### Troubleshooting:

1. **Diff doesn't appear**: Check if diff preview is enabled with `:ClaudeDiffToggle`
2. **Keys don't work**: Make sure the diff window is focused and you're in normal mode
3. **Want to share MCP server across sessions**: Set a custom `server_name` in config

## Advanced Configuration

### Custom MCP Server Name

If you want to share the same MCP server configuration across multiple Neovim sessions (e.g., for a team setup):

```lua
require("claucode").setup({
  mcp = {
    server_name = "my-team-claucode", -- Fixed name instead of session-specific
  },
})
```

⚠️ **Warning:** Using a fixed server name means diff requests might appear in any running Neovim instance that uses the same name. Only do this if you understand the implications.

## Configuration

In your Neovim config:

```lua
require("claucode").setup({
  bridge = {
    show_diff = true,  -- Enable diff preview
  },
  mcp = {
    enabled = true,    -- Enable MCP server
    server_name = nil, -- nil = auto-generate (recommended for multi-instance support)
  },
})
```