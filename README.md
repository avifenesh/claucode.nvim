# claucode.nvim

A Neovim bridge plugin for [Claude Code CLI](https://claude.ai/code), providing seamless integration between your editor and Claude's AI capabilities.

> 🌟 **Love this plugin?** Give it a star! It helps others discover it.

## What's This?

A lightweight Neovim plugin that bridges your editor with Claude Code CLI, bringing AI assistance directly into your coding workflow.

## Features

- 🚀 Send prompts to Claude directly from Neovim
- 📁 Auto-reload buffers when Claude modifies files
- 🔍 Visual selection support for context-aware assistance
- 📝 Include file context with your prompts
- 🔄 Real-time file watching for external changes
- 🖥️ Terminal integration with split view  
- 💬 Streaming responses in popup windows
- 🎯 MCP-powered diff preview - Review changes before applying
<img width="1000" height="900" alt="image" src="https://github.com/user-attachments/assets/95ed7731-dd22-4d96-a63c-bf9136ab368b" />

<img width="1000" height="671" alt="Screenshot 2025-08-04 at 6 31 51" src="https://github.com/user-attachments/assets/6dec7b8c-60a0-4d07-b298-e78168c6d8c8" />

<img width="1000" height="272" alt="Screenshot 2025-08-04 at 6 33 54" src="https://github.com/user-attachments/assets/7421b2ce-4051-4f34-b305-fdc6136be874" />

<img width="1000" height="900" alt="Screenshot 2025-08-04 at 6 38 33" src="https://github.com/user-attachments/assets/a9c189e4-b1e8-4fcf-a09f-994185f60f68" />

## Getting Started

### Prerequisites

- Neovim 0.5 or later
- [Claude Code CLI](https://claude.ai/code) (`npm install -g @anthropic-ai/claude-code`)
- `ANTHROPIC_API_KEY` environment variable or the app conncted using other login method

### Installation

**Using lazy.nvim** (recommended)
```lua
{
  "avifenesh/claucode.nvim",
  config = function()
    require("claucode").setup()
  end,
}
```

**Using packer.nvim**
```lua
use {
  "avifenesh/claucode.nvim",
  config = function()
    require("claucode").setup()
  end
}
```

## Configuration

```lua
require("claucode").setup({
  -- Claude Code CLI command (default: "claude")
  -- Use full path if claude is not in your PATH
  command = "claude",  -- or "/home/username/.claude/local/claude"

  -- Auto-start file watcher on setup
  auto_start_watcher = true,

  -- Enable default keymaps
  keymaps = {
    enable = true,
    prefix = "<leader>ai",  -- AI prefix to avoid conflicts
  },

  -- File watcher settings
  watcher = {
    debounce = 100,  -- milliseconds
    ignore_patterns = { "%.git/", "node_modules/", "%.swp$", "%.swo$" },
  },

  -- Bridge settings
  bridge = {
    timeout = 30000,     -- milliseconds
    max_output = 1048576, -- 1MB
    show_diff = false,   -- Enable diff preview (requires MCP, default: false)
  },

  -- MCP settings
  mcp = {
    enabled = true,      -- Enable MCP server (default: true)
    auto_build = true,   -- Auto-build MCP server if not found (default: true)
  },

  -- UI settings
  ui = {
    diff = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
    terminal = {
      height = 0.5, -- Terminal height as fraction of screen (0.5 = 50%)
    },
  },
})
```

## Usage

### MCP-Powered Diff Preview

This plugin includes an MCP (Model Context Protocol) server that provides seamless diff preview functionality. When enabled, you'll see exactly what changes Claude wants to make before they're applied to your files.

**Enable diff preview:**
```lua
require("claucode").setup({
  mcp = {
    enabled = true,     -- Enable MCP server (default: true)
    auto_build = true,  -- Auto-build MCP server if not found (default: true)
  },
  bridge = {
    show_diff = true,   -- Enable diff preview (requires MCP)
  }
})
```

**How it works:**
1. The plugin automatically adds its MCP server to your Claude configuration using `claude mcp add`
2. This preserves all your existing MCP servers while adding Neovim diff preview tools
3. Claude uses `nvim_edit_with_diff` and `nvim_write_with_diff` instead of standard file operations
4. When Claude wants to modify a file, a **side-by-side diff preview** appears:
   - Left window shows the original file content
   - Right window shows the proposed changes
   - Neovim's built-in diff highlighting shows exactly what will change
5. Review the changes and decide:
   - Press `a` to accept the changes
   - Press `r` to reject the changes
   - Press `q` or `<Esc>` to close (same as reject)
   - Press `Tab`, `<C-h>`, or `<C-l>` to switch between windows
6. The file is only modified after you approve the changes

**Requirements:**
- Node.js and npm (for building the MCP server)
- The MCP server will be automatically built on first use

### CLAUDE.md Integration

When diff preview is enabled, the plugin automatically adds instructions to your project's `CLAUDE.md` file. This ensures Claude will use the Neovim diff preview tools in both command mode and terminal mode.

**Automatic behavior:**
- When you enable `show_diff = true`, the plugin automatically adds diff preview instructions to CLAUDE.md
- This happens silently in the background when you open Neovim in a project
- To disable automatic CLAUDE.md updates, set `bridge.auto_claude_md = false`

**Benefits:**
- Works in both `:Claude` commands and `:ClaudeTerminal` automatically
- No need to remember flags or special commands
- Project-specific configuration that can be committed to version control
- Team members get the same behavior automatically

### Controlling Diff Preview at Runtime

You can toggle diff preview functionality at any time without restarting Neovim using:

```vim
:ClaudeDiffToggle
```

This command will:
1. Toggle the diff preview on/off
2. Start/stop the diff watcher process
3. Add/remove the MCP server from Claude's configuration
4. Automatically add/remove instructions from CLAUDE.md
5. Show a notification of the current state

**Important:** After toggling, you must restart any active Claude terminal sessions for the changes to take full effect. This is because:
- Claude loads CLAUDE.md instructions at session start
- MCP servers are registered/unregistered globally but active sessions keep their initial configuration

**Note:** Diff preview requires `mcp.enabled = true` in your configuration. If MCP is disabled, the toggle command will show a warning.

### Commands

- `:Claude <prompt>` - Send a prompt to Claude (shows response in popup)
- `:Claude --file <prompt>` - Include current file context with prompt
- `:ClaudeTerminal [cli_args]` - Open Claude in a terminal split with optional CLI parameters
- `:ClaudeTerminalToggle` - Toggle Claude terminal visibility
- `:ClaudeDiffToggle` - Toggle diff preview on/off

### Default Keymaps

With default prefix `<leader>ai`:

**Normal mode:**
- `<leader>aic` - Send prompt to Claude
- `<leader>aif` - Send current file to Claude for review
- `<leader>aie` - Explain code (selection or file)
- `<leader>aix` - Fix issues in code
- `<leader>ait` - Generate tests
- `<leader>aio` - Open Claude terminal
- `<leader>aiT` - Toggle Claude terminal

**Visual mode:**
- Select text then `<leader>aic` - Send selection with prompt
- Select text then `<leader>aiT` - Send selection to terminal

### Examples

```vim
" Ask Claude a question
:Claude How do I implement a binary search in Lua?

" Review current file
:Claude --file Please review this code and suggest improvements

" Visual mode: select code and ask for explanation
" Select code in visual mode, then:
:Claude Explain this code

" Fix issues in current file
:Claude --file Fix any bugs or issues in this file

" Open Claude terminal with CLI parameters
:ClaudeTerminal --continue
:ClaudeTerminal --mcp-config ../.mcp.json
:ClaudeTerminal --continue --mcp-config ../.mcp.json
```

## What This Is (and Isn't)

**This plugin IS:**
- 🌉 A bridge between Neovim and Claude Code CLI
- 📨 A way to send prompts without leaving your editor
- 👀 A file watcher that keeps your buffers in sync
- 🎯 Focused on doing one thing well

**This plugin is NOT:**
- 🤖 An AI implementation (Claude handles that)
- 🔮 A Copilot-style autocomplete tool
- 🎨 A comprehensive AI suite

It's a simple bridge - Claude does the AI work, this plugin handles the communication.

## Troubleshooting

### Claude commands not working?

1. **Check installation**: `npm install -g @anthropic-ai/claude-code`
2. **Verify API key**: `echo $ANTHROPIC_API_KEY`
3. **Test Claude directly**: `claude -p "test"`

### "Claude Code CLI not found" error?

Find Claude's location: `which claude`

Then update your config:
```lua
require("claucode").setup({
  command = "/path/to/claude",  -- e.g., "/home/user/.claude/local/claude"
})
```

### File watcher issues?

- Check ignore patterns in your config
- Verify file permissions
- The watcher auto-starts with the plugin

### Performance tips

- Adjust `watcher.debounce` (default: 100ms)
- Increase `bridge.timeout` for long operations
- Raise `bridge.max_output` if responses get cut off

## Contributing

Issues and PRs welcome! This is a community project.

## Philosophy

Built on the Unix principle: do one thing well.

- **Lightweight** - Minimal dependencies, fast startup
- **Focused** - Pure bridge functionality
- **Reliable** - Stable core features

## License

MIT
