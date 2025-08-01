# claucode.nvim

A community-driven Neovim bridge plugin for [Claude Code CLI](https://claude.ai/code), providing seamless integration between your editor and Claude's AI capabilities.

> 🌟 **Love this plugin?** Give it a star! It really helps others discover it and motivates development.

## What's This?

This is a lightweight bridge that connects Neovim with Claude Code CLI. It's a personal project I built to scratch my own itch, and I'm sharing it in case others find it useful too!

## Features

- 🚀 Send prompts to Claude directly from Neovim
- 📁 Automatic file change detection and buffer reloading
- 🔍 Visual selection support for targeted assistance
- 📝 File context inclusion with prompts
- 🔄 Real-time file watching for Claude's modifications
- 🖥️ Terminal integration - Run Claude in a split terminal
- 💬 Beautiful popup windows for Claude responses
- 🔍 **NEW**: MCP-powered diff preview - See changes before they're applied!

## Getting Started

### Before You Begin

Make sure you have:
- Neovim 0.5+ (because who doesn't love modern Neovim?)
- [Claude Code CLI](https://claude.ai/code) installed (`npm install -g @anthropic-ai/claude-code`)
- Your `ANTHROPIC_API_KEY` environment variable set

### Installation

Pick your favorite plugin manager:

**lazy.nvim** (recommended)
```lua
{
  "avifenesh/claucode.nvim",
  config = function()
    require("claucode").setup({
      -- your configuration (or just use defaults, they're pretty good!)
    })
  end,
}
```

**packer.nvim**
```lua
use {
  "avifenesh/claucode.nvim",
  config = function()
    require("claucode").setup({
      -- your configuration
    })
  end
}
```

That's it! No complex setup, no heavy dependencies. Just a simple bridge that gets out of your way.

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
1. The plugin provides an MCP server with Neovim-specific diff preview tools
2. Claude uses `nvim_edit_with_diff` and `nvim_write_with_diff` instead of standard file operations
3. A diff preview appears in Neovim before changes are applied
4. Review the changes and decide:
   - Press `a` to accept the changes
   - Press `r` to reject the changes  
   - Press `q` or `<Esc>` to close (same as reject)

**Requirements:**
- Node.js and npm (for building the MCP server)
- The MCP server will be automatically built on first use

### CLAUDE.md Integration

When diff preview is enabled, the plugin automatically adds instructions to your project's `CLAUDE.md` file. This ensures Claude will use the Neovim diff preview tools in both command mode and terminal mode.

**Automatic behavior:**
- When you enable `show_diff = true`, the plugin automatically adds diff preview instructions to CLAUDE.md
- This happens silently in the background when you open Neovim in a project
- To disable automatic CLAUDE.md updates, set `bridge.auto_claude_md = false`

**Manual control:**
- Use `:ClaudeDiffInstructions` to manually toggle the diff preview instructions in CLAUDE.md

**Benefits:**
- Works in both `:Claude` commands and `:ClaudeTerminal` automatically
- No need to remember flags or special commands
- Project-specific configuration that can be committed to version control
- Team members get the same behavior automatically

### Commands

- `:Claude <prompt>` - Send a prompt to Claude (shows response in popup)
- `:Claude --file <prompt>` - Include current file context with prompt
- `:ClaudeStop` - Stop Claude Code bridge and file watcher
- `:ClaudeStart` - Start file watcher
- `:ClaudeReview` - Review pending changes from Claude
- `:ClaudeTerminal [cli_args]` - Open Claude in a terminal split with optional CLI parameters
- `:ClaudeTerminalToggle` - Toggle Claude terminal visibility
- `:ClaudeTerminalSend <text>` - Send text to Claude terminal
- `:ClaudeDiffInstructions` - Toggle Neovim diff preview instructions in CLAUDE.md

### Default Keymaps

With default prefix `<leader>ai`:

**Normal mode:**
- `<leader>aic` - Send prompt to Claude
- `<leader>aif` - Send current file to Claude for review
- `<leader>aie` - Explain code (selection or file)
- `<leader>aix` - Fix issues in code
- `<leader>ait` - Generate tests
- `<leader>air` - Review pending changes
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

Let's be super clear about what you're getting:

**This plugin IS:**
- 🌉 A simple bridge between Neovim and Claude Code CLI
- 📨 A way to send prompts without leaving your editor
- 👀 A file watcher that keeps your buffers in sync
- 🎯 Focused on doing one thing well

**This plugin is NOT:**
- 🤖 An AI implementation (that's Claude's job)
- 🔮 A Copilot replacement
- 🎨 A feature-packed AI suite
- 👨‍💼 A professionally maintained product with SLAs

It's literally just a bridge. Claude does the AI stuff, this plugin just helps you talk to it from Neovim. Simple as that!

## Troubleshooting

### Commands not working

1. Ensure Claude Code CLI is installed: `npm install -g @anthropic-ai/claude-code`
2. Verify API key is set: `echo $ANTHROPIC_API_KEY`
3. Test Claude directly: `claude -p "test"`
4. **If "Claude Code CLI not found" error**:
   - Find where claude is installed: `which claude` in your terminal
   - Update your config with the full path:
     ```lua
     require("claucode").setup({
       command = "/full/path/to/claude",  -- e.g., "/home/user/.claude/local/claude"
     })
     ```
   - Or ensure Neovim inherits your PATH by starting it from your shell

### File watcher issues

- Check if files match ignore patterns
- Ensure proper file permissions
- Try manual reload with `:ClaudeStop` then `:ClaudeStart`

### Performance

- Adjust `watcher.debounce` for faster/slower file detection
- Increase `bridge.timeout` for longer operations
- Check `bridge.max_output` if responses are truncated

## Found a Bug?

Feel free to open an issue! Even better, if you've got a fix, I'd love to see a PR.

## Want a Feature?

Got a cool idea? Here's the thing - this is a side project I maintain in my spare time, so I can't promise I'll implement every request. But here's what you can do:

1. **Open an issue** describing your idea
2. **If I think it's cool and fits the project**, I'll probably add it when I get time
3. **Even better**: Fork the repo and implement it yourself! I'm happy to review PRs for features that align with the plugin's goals

Remember: The best features often come from contributors who needed them and built them. That's the beauty of open source! 🚀

## Show Some Love ❤️

If this plugin saves you time or makes your workflow better:

- ⭐ **Star the repo** - It helps others find it and honestly makes my day
- 💬 **Share your experience** - Drop a note in Issues about how you use it
- 🐛 **Report bugs** - Help make it better for everyone
- 🔧 **Contribute code** - PRs for bug fixes are always welcome

## Philosophy

This plugin follows the Unix philosophy: do one thing well. It's a bridge, not a replacement for Claude Code. It aims to be:

- **Lightweight** - Minimal dependencies, fast startup
- **Focused** - Just the bridge functionality, nothing more
- **Reliable** - If it works for my daily workflow, it should work for yours

## No Warranty, Just Community

This is provided as-is, with no guarantees. It works great for me, and I hope it works for you too! If something's broken, let's fix it together.

## License

MIT - Do whatever you want with it, just don't blame me if something goes wrong 😄