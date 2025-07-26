# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a community Neovim bridge plugin for Claude Code CLI. The plugin acts as a **bridge** between Neovim and Claude Code running in the terminal - it does NOT replace Claude Code or implement AI features directly. Instead, it facilitates seamless communication and integration between your editor and the CLI tool.

## Project Structure

```
claucode.nvim/
├── plan.md          # Comprehensive technical planning document
└── CLAUDE.md        # This file
```

## Current Architecture

The plugin follows a bridge architecture:

```lua
claude-code.nvim/
├── lua/claude-code/
│   ├── init.lua          -- Main module and setup
│   ├── bridge.lua        -- Core bridge for CLI communication
│   ├── watcher.lua       -- File watcher for Claude's changes
│   ├── commands.lua      -- User commands (:Claude, etc.)
│   ├── keymaps.lua       -- Keybinding definitions
│   └── review.lua        -- Diff preview and change review
```

## Development Commands

Since this is a Neovim plugin project in planning phase, typical development commands will include:

- **Testing**: Use Neovim's built-in testing framework or plenary.nvim for unit tests
- **Linting**: `luacheck .` for Lua code linting
- **Running**: Load the plugin in Neovim using the plugin manager of choice (lazy.nvim recommended)

## Key Technical Decisions

1. **Bridge Pattern**: Plugin connects Neovim ↔ Claude Code CLI via filesystem
2. **Communication**: File-based IPC using shared directory (future: MCP support)
3. **File Watching**: vim.loop (libuv) for detecting Claude's file changes
4. **UI Components**: Native diff view for reviewing changes
5. **Architecture**: Lightweight bridge, NOT a full AI implementation

## Integration Points

- **Claude Code CLI**: Communicates via subprocess using JSON protocol
- **Neovim APIs**: Uses modern Lua APIs introduced in Neovim 0.5+
- **LSP Integration**: Respects LSP boundaries and workspace folders for context
- **Plugin Ecosystem**: Designed to work alongside other AI plugins without conflicts

## Performance Considerations

- Lazy loading with event-based triggers
- Target sub-50ms startup time contribution
- Multi-level caching (memory and disk)
- Non-blocking UI updates via vim.schedule()
- Circuit breaker pattern for API reliability

## Context for Claude Code

When working on this codebase, remember this is a community plugin:

1. **Compatibility First**: Support Neovim 0.5+ and multiple platforms (Linux, macOS, Windows)
2. **User-Friendly**: Provide sensible defaults that work out-of-the-box for most users
3. **Accessible**: Clear documentation, helpful error messages, and intuitive commands
4. **Performance**: Non-blocking operations while being mindful of system resources
5. **Flexibility**: Configurable options to accommodate different workflows and preferences
6. **Error Handling**: Graceful degradation with informative feedback when issues occur
7. **Community Standards**: Follow established Neovim plugin patterns and conventions

## Community Considerations

- **Installation**: Support multiple plugin managers (lazy.nvim, packer, vim-plug)
- **Dependencies**: Minimize external dependencies; clearly document any requirements
- **Configuration**: Provide sensible defaults with extensive customization options
- **Documentation**: Include examples for common use cases
- **Testing**: Ensure broad compatibility across different environments
- **Accessibility**: Consider users with different skill levels and system configurations

## IMPORTANT: Core Design Principle

**This is a BRIDGE plugin, not an AI plugin.** The plugin facilitates communication between Neovim and Claude Code CLI but does NOT:
- ❌ Implement autocomplete/inline suggestions
- ❌ Replace Claude Code's functionality
- ❌ Run AI models inside Neovim
- ❌ Act like GitHub Copilot

Instead, it DOES:
- ✅ Send prompts from Neovim to Claude Code CLI
- ✅ Share file context with Claude Code
- ✅ Detect and show file changes made by Claude
- ✅ Provide quick commands for common tasks
- ✅ Keep Neovim and CLI in sync

## User Workflow

1. User runs Claude Code in terminal: `claude`
2. User opens Neovim in the same project
3. User can send prompts from Neovim: `:Claude fix this`
4. Claude processes in terminal and edits files
5. Plugin detects changes and reloads buffers
6. User reviews changes with diff preview

## Future Enhancements

- MCP (Model Context Protocol) support for advanced communication
- Terminal integration for embedded Claude Code view
- Enhanced diff review with partial accept/reject
- Project-wide context sharing