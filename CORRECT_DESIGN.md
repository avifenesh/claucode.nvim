# Claude Code Neovim Plugin - Correct Design

## Understanding Claude Code CLI

Claude Code is a **terminal-based** AI coding assistant that:
- Runs in your terminal (not inside the editor)
- Can read and edit files in your project
- Maintains conversation context
- Executes commands with your permission

## Plugin Purpose

The Neovim plugin should **bridge** between Neovim and the Claude Code CLI, NOT replace it. The plugin should:

1. **Share Context** - Send current file/selection to Claude Code CLI
2. **Show Changes** - Display file changes made by Claude Code in Neovim
3. **Quick Actions** - Fast ways to send prompts from Neovim
4. **Sync State** - Keep Neovim and CLI in sync

## Core Features (What We Actually Need)

### 1. Context Sharing
```lua
-- Send current file to Claude Code's context
:ClaudeContext              -- Share current buffer
:ClaudeContext %            -- Share current file
:ClaudeContext selection    -- Share visual selection
```

### 2. File Change Detection
- Watch for file changes made by Claude Code
- Automatically reload buffers when Claude edits them
- Show diff preview when Claude proposes changes

### 3. Quick Prompts
```lua
-- Quick way to send prompts without switching to terminal
:Claude fix this function
:Claude add error handling to selection
:Claude explain this code
```

### 4. Terminal Integration
- Optional: Show Claude Code terminal in split/float
- Send commands to Claude Code terminal
- See Claude's responses without leaving Neovim

### 5. Diff Integration
- When Claude shows diffs in terminal, preview them in Neovim
- Accept/reject changes from within Neovim
- Similar to reviewing git changes

## What We DON'T Need

❌ Autocomplete/inline suggestions (like Copilot)
❌ Replace Claude Code CLI functionality
❌ AI running inside Neovim
❌ Complex completion sources

## Correct Architecture

```
┌─────────────────┐         ┌──────────────────┐
│                 │         │                  │
│    Neovim       │ <-----> │  Claude Code CLI │
│                 │         │   (Terminal)     │
│  - Edit files   │         │                  │
│  - Quick prompts│         │  - AI brain      │
│  - Show diffs   │         │  - Conversations │
│  - Sync changes │         │  - File edits    │
│                 │         │                  │
└─────────────────┘         └──────────────────┘
        ↑                            ↑
        └────────────┬───────────────┘
                     │
              File System &
              IPC/Sockets
```

## Implementation Approach

### 1. File Watcher
```lua
-- Watch for changes to files in current project
local watcher = vim.loop.new_fs_event()
watcher:start(project_root, {
  recursive = true
}, function(err, filename, events)
  -- Reload buffer if Claude edited it
  if events.change then
    reload_buffer_if_open(filename)
  end
end)
```

### 2. Quick Prompt System
```lua
-- Send prompt to Claude Code CLI
function M.send_prompt(prompt)
  -- Option 1: Write to Claude's stdin if we have process handle
  -- Option 2: Use temp file + file watcher pattern
  -- Option 3: Use named pipes/sockets
end
```

### 3. Context Sharing
```lua
-- Share current context with Claude
function M.share_context()
  local current_file = vim.api.nvim_buf_get_name(0)
  -- Tell Claude to look at this file
  M.send_prompt("Look at " .. current_file)
end
```

### 4. Diff Preview
```lua
-- When Claude proposes changes, show them
function M.preview_changes(file, proposed_content)
  -- Create diff view
  -- Allow accept/reject
end
```

## User Workflow

1. **Start Claude Code** in terminal: `claude`
2. **Open Neovim** in the same project
3. **Work normally** in Neovim
4. **Quick prompt**: `:Claude refactor this function`
5. **See changes**: Claude edits file → Neovim auto-reloads
6. **Review diffs**: When Claude shows changes
7. **Continue conversation** in terminal when needed

## Integration Examples

### With Telescope
```lua
-- Quick actions menu
:Telescope claude_actions
> Fix current function
> Add documentation
> Explain selection
> Run tests
```

### With Fugitive/Git
```lua
-- When Claude makes changes
:Gstatus  -- See what Claude changed
:Gdiff    -- Review Claude's changes
```

## Benefits of This Approach

✅ Respects Claude Code's design philosophy
✅ No duplicate functionality
✅ Seamless workflow between terminal and editor
✅ Lightweight and fast
✅ Works with existing Claude Code features
✅ Easy to understand and maintain

## What Makes This Different

Unlike Copilot-style plugins:
- **Not inline completion** - Claude Code is conversational
- **Not automatic** - User controls when to engage
- **Terminal-first** - Respects Unix philosophy
- **Project-aware** - Understands entire codebase
- **Action-oriented** - Can run commands, create files, etc.

This is the correct approach for a Claude Code Neovim plugin!