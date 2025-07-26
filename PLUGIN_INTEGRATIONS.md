# Claude Code Plugin Integration Plan

This document outlines how claude-code.nvim will integrate with popular Neovim plugins to create a seamless AI-enhanced development experience.

## Core Integration Philosophy

1. **Non-invasive**: Never override existing plugin functionality
2. **Opt-in**: All integrations should be configurable
3. **Graceful degradation**: Work without optional dependencies
4. **Performance-first**: Lazy load integration code
5. **Familiar patterns**: Use conventions from each plugin's ecosystem

## Priority 1: Essential Integrations

### 1. nvim-cmp Integration
**Plugin**: hrsh7th/nvim-cmp
**Purpose**: Seamless AI completions alongside LSP

```lua
-- lua/claude-code/integrations/cmp.lua
local source = {}

function source:is_available()
  return require('claude-code.process').is_running()
end

function source:get_debug_name()
  return 'claude-code'
end

function source:get_trigger_characters()
  return { '.', ':', '(', '{', '[', ' ', '\n' }
end

function source:complete(params, callback)
  local context = params.context
  local cursor = context.cursor
  
  require('claude-code.actions').get_completions({
    line = context.cursor_line,
    col = cursor.col,
    prefix = string.sub(context.cursor_line, 1, cursor.col - 1),
    filetype = vim.bo.filetype,
  }, function(items)
    callback({
      items = vim.tbl_map(function(item)
        return {
          label = item.label,
          kind = require('cmp').lsp.CompletionItemKind.Text,
          detail = 'Claude Code',
          documentation = item.description,
          sortText = item.priority,
        }
      end, items),
      isIncomplete = true,
    })
  end)
end

-- Registration
require('cmp').register_source('claude_code', source)
```

**User Configuration**:
```lua
sources = cmp.config.sources({
  { name = 'nvim_lsp' },
  { name = 'claude_code', priority = 80 }, -- Lower than LSP
  { name = 'buffer' },
})
```

### 2. Telescope Integration
**Plugin**: nvim-telescope/telescope.nvim
**Purpose**: Command palette, code search, and project navigation

```lua
-- lua/claude-code/integrations/telescope.lua
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local M = {}

-- Slash command picker
M.slash_commands = function(opts)
  opts = opts or {}
  
  local commands = require('claude-code.commands').get_slash_commands()
  
  pickers.new(opts, {
    prompt_title = 'Claude Code Commands',
    finder = finders.new_table({
      results = commands,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name .. ' - ' .. entry.description,
          ordinal = entry.name .. ' ' .. entry.description,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd('ClaudeCode ' .. selection.value.name)
      end)
      return true
    end,
  }):find()
end

-- Semantic code search
M.code_search = function(opts)
  opts = opts or {}
  
  vim.ui.input({
    prompt = 'Search for: ',
  }, function(query)
    if not query then return end
    
    require('claude-code.actions').semantic_search({
      query = query,
      project_root = vim.fn.getcwd(),
    }, function(results)
      pickers.new(opts, {
        prompt_title = 'Claude Code Search: ' .. query,
        finder = finders.new_table({
          results = results,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.file .. ':' .. entry.line .. ' - ' .. entry.preview,
              ordinal = entry.file .. ' ' .. entry.content,
              filename = entry.file,
              lnum = entry.line,
              col = entry.col,
            }
          end,
        }),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter(opts),
      }):find()
    end)
  end)
end

return M
```

**User Commands**:
```vim
:Telescope claude_commands
:Telescope claude_search
:Telescope claude_agents
:Telescope claude_templates
```

### 3. LSP Integration
**Purpose**: Enhance LSP with AI capabilities

```lua
-- lua/claude-code/integrations/lsp.lua
local M = {}

-- Add AI-powered code actions
M.setup_code_actions = function()
  local original_code_action = vim.lsp.buf.code_action
  
  vim.lsp.buf.code_action = function()
    -- Get standard LSP code actions
    local params = vim.lsp.util.make_range_params()
    local results = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params)
    
    -- Add Claude Code actions
    local claude_actions = {
      {
        title = "🤖 Explain this code",
        kind = "claude.explain",
      },
      {
        title = "🤖 Add documentation",
        kind = "claude.document",
      },
      {
        title = "🤖 Write tests",
        kind = "claude.test",
      },
      {
        title = "🤖 Optimize performance",
        kind = "claude.optimize",
      },
      {
        title = "🤖 Fix issues",
        kind = "claude.fix",
      },
    }
    
    -- Merge and show in telescope
    local all_actions = vim.list_extend(results or {}, claude_actions)
    require('telescope.pickers').new({}, {
      prompt_title = 'Code Actions',
      finder = require('telescope.finders').new_table({
        results = all_actions,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.title,
            ordinal = entry.title,
          }
        end,
      }),
      -- ... rest of picker config
    }):find()
  end
end

-- Enhanced hover with AI explanations
M.setup_hover = function()
  local original_hover = vim.lsp.buf.hover
  
  vim.lsp.buf.hover = function()
    -- Show LSP hover first
    original_hover()
    
    -- Add keybinding in hover window for AI explanation
    vim.keymap.set('n', 'K', function()
      local word = vim.fn.expand('<cword>')
      require('claude-code.actions').explain_symbol(word)
    end, { buffer = true })
  end
end

return M
```

## Priority 2: Git & Project Management

### 4. Fugitive/Neogit Integration
**Purpose**: AI-powered git operations

```lua
-- lua/claude-code/integrations/git.lua
local M = {}

-- Smart commit messages
M.create_commit_message = function()
  local changes = vim.fn.system('git diff --cached')
  
  require('claude-code.actions').generate_commit_message({
    changes = changes,
    type = 'conventional', -- or 'descriptive'
  }, function(message)
    -- For fugitive
    if vim.fn.exists(':Gcommit') > 0 then
      vim.cmd('Gcommit')
      vim.api.nvim_put(vim.split(message, '\n'), 'l', true, true)
    end
    
    -- For neogit
    if package.loaded['neogit'] then
      require('neogit').open({ 'commit' })
      vim.defer_fn(function()
        vim.api.nvim_put(vim.split(message, '\n'), 'l', true, true)
      end, 100)
    end
  end)
end

-- PR description generator
M.create_pr_description = function()
  local branch_diff = vim.fn.system('git diff main...HEAD')
  local commits = vim.fn.system('git log main..HEAD --oneline')
  
  require('claude-code.actions').generate_pr_description({
    diff = branch_diff,
    commits = commits,
  }, function(description)
    -- Copy to clipboard
    vim.fn.setreg('+', description)
    vim.notify('PR description copied to clipboard')
  end)
end

return M
```

### 5. neo-tree.nvim Integration
**Purpose**: File tree context menu additions

```lua
-- lua/claude-code/integrations/neo-tree.lua
local M = {}

M.setup = function()
  require('neo-tree').setup({
    filesystem = {
      window = {
        mappings = {
          ["<C-a>"] = {
            command = function(state)
              local node = state.tree:get_node()
              local path = node.path
              
              vim.ui.select({
                "Explain this file",
                "Add tests for this file",
                "Add documentation",
                "Refactor this file",
                "Find similar files",
              }, {
                prompt = "Claude Code action:",
              }, function(choice)
                if choice == "Explain this file" then
                  require('claude-code.actions').explain_file(path)
                elseif choice == "Add tests for this file" then
                  require('claude-code.actions').generate_tests(path)
                -- ... etc
                end
              end)
            end,
            desc = "Claude Code actions"
          },
        },
      },
    },
  })
end

return M
```

## Priority 3: Enhanced Development

### 6. Trouble.nvim Integration
**Purpose**: AI-powered diagnostics and fixes

```lua
-- lua/claude-code/integrations/trouble.lua
local M = {}

M.setup = function()
  -- Add custom action to trouble
  require('trouble').setup({
    action_keys = {
      fix_with_claude = {
        key = "<C-f>",
        action = function(view)
          local item = view:get_current_item()
          if item and item.diagnostic then
            require('claude-code.actions').fix_diagnostic({
              diagnostic = item.diagnostic,
              file = item.filename,
              line = item.lnum,
            })
          end
        end,
        desc = "Fix with Claude Code",
      },
      explain_error = {
        key = "<C-e>",
        action = function(view)
          local item = view:get_current_item()
          if item and item.diagnostic then
            require('claude-code.actions').explain_error({
              message = item.diagnostic.message,
              code = item.diagnostic.code,
              source = item.diagnostic.source,
            })
          end
        end,
        desc = "Explain error",
      },
    },
  })
end

return M
```

### 7. nvim-dap Integration
**Purpose**: AI-assisted debugging

```lua
-- lua/claude-code/integrations/dap.lua
local M = {}

M.setup = function()
  local dap = require('dap')
  
  -- Add AI debugging assistant
  dap.listeners.after.event_stopped['claude_code'] = function(session, body)
    if body.reason == 'exception' then
      -- Automatically analyze exceptions
      require('claude-code.actions').analyze_exception({
        exception = body.exception,
        stack_trace = session.threads,
        variables = session.scopes,
      }, function(analysis)
        -- Show in floating window
        require('claude-code.ui').show_analysis(analysis)
      end)
    end
  end
  
  -- Custom debugging commands
  vim.api.nvim_create_user_command('ClaudeDebugAnalyze', function()
    local variables = require('dap.ui.widgets').scopes()
    require('claude-code.actions').analyze_debug_state({
      variables = variables,
      breakpoints = require('dap.breakpoints').get(),
    })
  end, {})
end

return M
```

### 8. which-key.nvim Integration
**Purpose**: Discoverable keybindings

```lua
-- lua/claude-code/integrations/which-key.lua
local M = {}

M.setup = function()
  local wk = require('which-key')
  
  wk.register({
    c = {
      name = "Claude Code",
      c = { "<cmd>ClaudeComplete<cr>", "Complete at cursor" },
      e = { "<cmd>ClaudeEdit<cr>", "Edit selection" },
      t = { "<cmd>ClaudeChat<cr>", "Open chat" },
      r = { "<cmd>ClaudeRefactor<cr>", "Refactor code" },
      x = { "<cmd>ClaudeExplain<cr>", "Explain code" },
      d = { "<cmd>ClaudeDocument<cr>", "Add documentation" },
      f = { "<cmd>ClaudeFix<cr>", "Fix issues" },
      s = {
        name = "Search",
        s = { "<cmd>Telescope claude_search<cr>", "Semantic search" },
        c = { "<cmd>Telescope claude_commands<cr>", "Commands" },
      },
      g = {
        name = "Git",
        c = { require('claude-code.integrations.git').create_commit_message, "Generate commit message" },
        p = { require('claude-code.integrations.git').create_pr_description, "Generate PR description" },
      },
    },
  }, { prefix = "<leader>" })
end

return M
```

## Priority 4: UI Enhancements

### 9. lualine.nvim Integration
**Purpose**: Status line indicators

```lua
-- lua/claude-code/integrations/lualine.lua
local M = {}

M.component = {
  function()
    if require('claude-code.process').is_running() then
      local stats = require('claude-code').get_stats()
      return string.format('🤖 Claude (%s)', stats.model)
    end
    return ''
  end,
  cond = function()
    return require('claude-code.process').is_running()
  end,
  color = { fg = '#7aa2f7' },
}

M.progress_component = {
  function()
    local progress = require('claude-code.ui.progress').get_current()
    if progress then
      return string.format('⟳ %s', progress.message)
    end
    return ''
  end,
  cond = function()
    return require('claude-code.ui.progress').is_active()
  end,
  color = { fg = '#f7768e' },
}

return M
```

### 10. noice.nvim Integration
**Purpose**: Better notifications and command line

```lua
-- lua/claude-code/integrations/noice.lua
local M = {}

M.setup = function()
  require('noice').setup({
    routes = {
      -- Route Claude Code messages to notification area
      {
        filter = { event = "msg_show", find = "Claude Code:" },
        view = "notify",
        opts = { title = "Claude Code" },
      },
      -- Show streaming responses in special view
      {
        filter = { event = "claude_streaming" },
        view = "split",
        opts = { enter = false, size = "20%" },
      },
    },
    -- Custom command line for Claude input
    commands = {
      ClaudeInput = {
        view = "cmdline_popup",
        opts = {
          prompt = "🤖 ",
          title = " Claude Code ",
          border = { style = "rounded" },
        },
      },
    },
  })
end

return M
```

## Integration Configuration

Users can enable/disable specific integrations:

```lua
require('claude-code').setup({
  integrations = {
    cmp = {
      enabled = true,
      priority = 80,
    },
    telescope = {
      enabled = true,
      mappings = true,
    },
    lsp = {
      enabled = true,
      code_actions = true,
      hover = true,
    },
    git = {
      enabled = true,
      auto_commit_message = false,
    },
    neo_tree = {
      enabled = true,
      context_menu = true,
    },
    trouble = {
      enabled = true,
      auto_fix = false,
    },
    dap = {
      enabled = true,
      auto_analyze = true,
    },
    which_key = {
      enabled = true,
      prefix = "<leader>c",
    },
    lualine = {
      enabled = true,
      section = 'x',
    },
    noice = {
      enabled = true,
      streaming_view = true,
    },
  },
})
```

## Implementation Strategy

1. **Core First**: Implement plugin core without integrations
2. **Optional Dependencies**: Use pcall to load integrations
3. **Gradual Rollout**: Release integrations one by one
4. **User Feedback**: Iterate based on community needs
5. **Performance Testing**: Ensure no startup time regression

## Testing Plan

Each integration needs:
1. Unit tests for API functions
2. Integration tests with real plugins
3. Performance benchmarks
4. Documentation examples
5. Video demonstrations

This comprehensive integration plan ensures claude-code.nvim becomes a natural extension of the Neovim ecosystem, enhancing rather than replacing existing workflows.