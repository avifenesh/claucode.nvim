# Testing Diff Preview Feature

## Setup
1. Make sure your Neovim config has `show_diff = true`:
```lua
require('claucode').setup({
  bridge = {
    show_diff = true,  -- Enable diff preview
  }
})
```

2. Restart Neovim after changing the config

## Test Commands

### Test 1: Simple file edit
```vim
:Claude please add a new function called greet() to test_simple.lua that prints "Hello!"
```

### Test 2: Edit existing function
```vim
:Claude modify the test() function in test_simple.lua to accept a parameter
```

### Test 3: Multiple changes
```vim
:Claude add error handling to all functions in test_diff_feature.lua
```

## Expected Behavior
- When Claude tries to modify a file, you should see:
  1. "Diff preview enabled - using permission mode: ask" notification
  2. "Permission request for tool: Edit" or "Write" notification
  3. A floating window showing the diff
  4. Press 'a' to accept, 'r' to reject changes

## ClaudeTerminal Support
The diff preview now also works with `:ClaudeTerminal`!
- When you open ClaudeTerminal with `show_diff = true`, it will automatically use `--permission-mode ask`
- You'll see "Claude Terminal: Diff preview enabled" notification
- Any file edits made in the terminal will show the diff preview
- This works for both interactive conversations and direct file editing commands

## Debugging
- Check `:messages` for debug output
- The bridge.lua now has debug logging enabled
- Look for "Claude event:" messages to see what events are being received