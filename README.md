# claude-code.nvim

Neovim bridge plugin for Claude Code CLI - Connect Neovim with Claude Code running in your terminal.

![Neovim](https://img.shields.io/badge/Neovim-0.7%2B-green.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## What is this?

This plugin creates a **bridge** between Neovim and the Claude Code CLI. It does NOT replace Claude Code or run AI inside Neovim. Instead, it:

- 📤 Sends context from Neovim to Claude Code CLI
- 📥 Shows file changes made by Claude in Neovim  
- ⚡ Provides quick prompts without switching windows
- 🔄 Keeps your editor and CLI in sync

## How it works

```
┌─────────────────┐         ┌──────────────────┐
│    Neovim       │ <-----> │  Claude Code CLI │
│                 │         │   (Terminal)     │
│  You edit here  │         │  Claude runs here│
└─────────────────┘         └──────────────────┘
        ↑                            ↑
        └────── Bridge Plugin ───────┘
```

## Requirements

- Neovim >= 0.7.0
- Node.js and npm (for Claude Code CLI installation)
- Claude Code CLI installed: `npm install -g @anthropic-ai/claude-code`
- A Claude account with active billing or Claude Pro/Max subscription

## Installation

### Using lazy.nvim

```lua
{
  "anthropics/claude-code.nvim",
  config = function()
    require("claude-code").setup()
  end,
}
```

### Using packer.nvim

```lua
use {
  'anthropics/claude-code.nvim',
  config = function()
    require('claude-code').setup()
  end
}
```

## Quick Start

1. **Start Claude Code** in your terminal:
   ```bash
   cd your-project
   claude
   ```

2. **Open Neovim** in the same project

3. **Use the bridge**:
   - `:Claude fix this function` - Send quick prompt
   - `:ClaudeContext` - Share current file with Claude
   - `<leader>cp` - Quick prompt with keybinding

4. **When Claude edits files**, Neovim auto-reloads them!

## Configuration

```lua
require('claude-code').setup({
  -- File watching
  watcher = {
    enabled = true,      -- Watch for Claude's changes
    auto_reload = true,  -- Auto-reload changed files
    diff_preview = true, -- Preview changes before applying
  },
  
  -- Quick prompts
  prompts = {
    fix = "Fix the issues in this code",
    explain = "Explain what this code does",
    improve = "Improve this code",
    test = "Write tests for this code",
    document = "Add documentation",
  },
  
  -- Keymaps
  keymaps = {
    quick_prompt = '<leader>cc',    -- Send prompt to Claude
    share_context = '<leader>cx',   -- Share context (x for conteXt)
    review_changes = '<leader>cd',  -- Review diff (d for diff)
  },
})
```

## Commands

### Core Commands

- `:Claude [prompt]` - Send a prompt to Claude Code
- `:ClaudeContext [selection]` - Share current file/selection
- `:ClaudeReview` - Review pending changes from Claude
- `:ClaudeStatus` - Check connection status

### Quick Action Commands

- `:ClaudeFix` - Ask Claude to fix issues
- `:ClaudeExplain` - Ask Claude to explain code
- `:ClaudeImprove` - Ask Claude to improve code
- `:ClaudeTest` - Ask Claude to write tests
- `:ClaudeDocument` - Ask Claude to add docs

## Keybindings

Default keybindings (customizable):

- `<leader>cc` - Send prompt to Claude
- `<leader>cx` - Share context with Claude
- `<leader>cd` - Review diff/changes from Claude

In visual mode, these commands include your selection!

## Workflow Example

1. Working on a function with a bug:
   ```vim
   :Claude fix the null pointer issue in this function
   ```

2. Claude analyzes and edits the file in the terminal

3. Neovim detects the change and shows a diff:
   ```
   Claude modified: src/main.js
   Press 'a' to accept, 'r' to reject
   ```

4. You review and accept the changes

## Troubleshooting

### Claude Code not connected?

1. Make sure Claude Code is running in your terminal
2. Check `:ClaudeStatus` for connection info
3. Both Neovim and Claude Code must be in the same project directory

### Changes not appearing?

- Try `:ClaudeReload` to manually refresh
- Check if file watching is enabled in config
- Ensure you have write permissions

## License

MIT

## Contributing

This is a community bridge plugin. Contributions welcome!

- Report issues: [GitHub Issues](https://github.com/anthropics/claude-code.nvim/issues)
- Submit PRs: Fork and create a pull request

## Not a Copilot!

This plugin is NOT:
- ❌ An autocomplete tool
- ❌ Inline AI suggestions
- ❌ A replacement for Claude Code CLI

It IS:
- ✅ A bridge between Neovim and Claude Code
- ✅ A way to use Claude Code without leaving Neovim
- ✅ A tool for seamless editor-CLI integration