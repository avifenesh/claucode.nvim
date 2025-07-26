-- Example configuration showcasing enhanced claude-code.nvim features
-- This demonstrates the proposed improvements and integrations

return {
  -- Claude Code plugin with enhanced features
  {
    "your-username/claude-code.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",           -- For completion integration
      "nvim-telescope/telescope.nvim", -- For command palette
      "folke/which-key.nvim",        -- For keybinding discovery
    },
    event = "VeryLazy",
    
    config = function()
      require("claude-code").setup({
        -- Core settings
        command = 'claude',
        model = 'sonnet',
        auto_start = true,
        
        -- Enhanced context awareness
        context = {
          -- Intelligent context gathering
          smart_context = true,
          max_lines = 1000,
          include_diagnostics = true,
          include_git_diff = true,
          
          -- File patterns to always include
          always_include = {
            "**/*.test.*",
            "**/types.*",
            "**/*.d.ts",
          },
        },
        
        -- Improved UI
        ui = {
          -- Floating diff preview
          diff_preview = {
            enabled = true,
            auto_show = true,
            keymaps = {
              accept = "<CR>",
              reject = "<Esc>",
              accept_line = "<C-y>",
              reject_line = "<C-n>",
            },
          },
          
          -- Enhanced chat
          chat = {
            width = 0.8,
            height = 0.8,
            border = 'rounded',
            
            -- Chat presets
            presets = {
              explain = "Explain this code in simple terms",
              optimize = "Optimize this code for performance",
              secure = "Review this code for security issues",
              test = "Write comprehensive tests for this code",
            },
          },
          
          -- Progress indicators
          progress = {
            enabled = true,
            show_in_statusline = true,
            spinner = {'⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'},
          },
        },
        
        -- Keymaps with which-key integration
        keymaps = {
          enable = true,
          prefix = "<leader>c",
          
          -- Enhanced mappings
          mappings = {
            c = { "<cmd>ClaudeComplete<cr>", "Complete at cursor" },
            e = { "<cmd>ClaudeEdit<cr>", "Edit selection" },
            t = { "<cmd>ClaudeChat<cr>", "Toggle chat" },
            
            -- New features
            r = {
              name = "Refactor",
              r = { "<cmd>ClaudeRefactor<cr>", "Refactor code" },
              n = { "<cmd>ClaudeRename<cr>", "Rename symbol" },
              e = { "<cmd>ClaudeExtract<cr>", "Extract function" },
              i = { "<cmd>ClaudeInline<cr>", "Inline variable" },
            },
            
            x = {
              name = "Explain", 
              x = { "<cmd>ClaudeExplain<cr>", "Explain code" },
              e = { "<cmd>ClaudeExplainError<cr>", "Explain error" },
              d = { "<cmd>ClaudeExplainDiff<cr>", "Explain diff" },
            },
            
            g = {
              name = "Git",
              c = { "<cmd>ClaudeCommit<cr>", "Generate commit message" },
              p = { "<cmd>ClaudePR<cr>", "Generate PR description" },
              r = { "<cmd>ClaudeReview<cr>", "Review changes" },
            },
            
            s = {
              name = "Search",
              s = { "<cmd>Telescope claude_search<cr>", "Semantic search" },
              c = { "<cmd>Telescope claude_commands<cr>", "Commands" },
              a = { "<cmd>Telescope claude_agents<cr>", "Agents" },
              t = { "<cmd>Telescope claude_templates<cr>", "Templates" },
            },
            
            d = { "<cmd>ClaudeDocument<cr>", "Add documentation" },
            f = { "<cmd>ClaudeFix<cr>", "Fix issues" },
            i = { "<cmd>ClaudeImplement<cr>", "Implement interface" },
          },
        },
        
        -- Plugin integrations
        integrations = {
          -- nvim-cmp integration
          cmp = {
            enabled = true,
            priority = 80,
            
            -- Intelligent filtering
            filter_in_comments = false,
            filter_in_strings = true,
            
            -- Multi-line completions
            multiline = {
              enabled = true,
              preview = true,
              max_lines = 10,
            },
          },
          
          -- Telescope integration
          telescope = {
            enabled = true,
            
            -- Semantic search settings
            search = {
              max_results = 50,
              include_tests = true,
              include_docs = true,
            },
          },
          
          -- LSP integration
          lsp = {
            enabled = true,
            
            -- Enhanced code actions
            code_actions = {
              enabled = true,
              priority = 100, -- Show AI actions first
            },
            
            -- AI-powered hover
            hover = {
              enabled = true,
              show_examples = true,
              show_related = true,
            },
          },
          
          -- Git integration
          git = {
            enabled = true,
            
            -- Commit message generation
            commit = {
              conventional = true,
              include_diff_summary = true,
              max_length = 72,
            },
            
            -- PR descriptions
            pull_request = {
              template = "default",
              include_test_plan = true,
              include_checklist = true,
            },
          },
          
          -- File tree integration
          neo_tree = {
            enabled = true,
            show_in_context_menu = true,
          },
          
          -- Diagnostics integration
          trouble = {
            enabled = true,
            auto_fix = false,
            explain_errors = true,
          },
          
          -- Debugging integration
          dap = {
            enabled = true,
            analyze_exceptions = true,
            suggest_breakpoints = true,
          },
          
          -- Status line
          lualine = {
            enabled = true,
            section = 'x',
            show_model = true,
            show_costs = false,
          },
          
          -- Notifications
          noice = {
            enabled = true,
            show_progress = true,
            show_confirmations = true,
          },
        },
        
        -- MCP (Model Context Protocol) settings
        mcp = {
          enabled = true,
          
          -- Auto-discover local MCP servers
          auto_discover = true,
          
          -- Pre-configured servers
          servers = {
            -- PostgreSQL integration
            {
              name = "postgres",
              command = "mcp-postgres",
              args = {"--connection", "$DATABASE_URL"},
              auto_start = false,
            },
            
            -- Documentation server
            {
              name = "docs", 
              command = "mcp-docs",
              args = {"--root", "./docs"},
              auto_start = true,
            },
          },
        },
        
        -- Templates for common tasks
        templates = {
          -- Function templates
          test_function = [[
Write comprehensive tests for this function including:
- Happy path tests
- Edge cases
- Error conditions
- Performance considerations
Use {test_framework} framework
          ]],
          
          -- Refactoring templates
          extract_function = [[
Extract the selected code into a well-named function.
Consider:
- Appropriate parameters
- Return values
- Error handling
- Documentation
          ]],
          
          -- Documentation templates
          add_docs = [[
Add comprehensive documentation including:
- Purpose and overview
- Parameters with types
- Return value description
- Example usage
- Potential errors
          ]],
        },
        
        -- Performance settings
        performance = {
          -- Request debouncing
          debounce_ms = 300,
          
          -- Caching
          cache = {
            enabled = true,
            ttl = 900000, -- 15 minutes
            max_size = "100MB",
          },
          
          -- Background operations
          background = {
            prefetch_completions = true,
            analyze_on_save = true,
          },
        },
        
        -- Advanced features
        advanced = {
          -- Code review mode
          review_mode = {
            enabled = true,
            auto_enable_on_pr = true,
            checklist = {
              "security",
              "performance", 
              "maintainability",
              "test_coverage",
            },
          },
          
          -- Learning mode
          learning_mode = {
            enabled = false,
            explain_level = "beginner", -- beginner, intermediate, advanced
            show_resources = true,
          },
          
          -- Multi-file operations
          multi_file = {
            enabled = true,
            preview_changes = true,
            atomic_operations = true,
          },
        },
      })
    end,
  },
  
  -- Enhanced nvim-cmp configuration
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      -- Add Claude Code as a source
      table.insert(opts.sources, 1, {
        name = "claude_code",
        priority = 80,
        -- Show Claude items with a special icon
        entry_filter = function(entry)
          entry.kind_icon = "🤖"
          return true
        end,
      })
      
      -- Custom sorting to prioritize Claude suggestions when relevant
      opts.sorting = {
        priority_weight = 2,
        comparators = {
          require("claude-code.integrations.cmp").compare_claude_priority,
          require("cmp.config.compare").offset,
          require("cmp.config.compare").exact,
          require("cmp.config.compare").score,
          require("cmp.config.compare").recently_used,
          require("cmp.config.compare").kind,
          require("cmp.config.compare").sort_text,
          require("cmp.config.compare").length,
          require("cmp.config.compare").order,
        },
      }
      
      return opts
    end,
  },
  
  -- Telescope extension
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions.claude_code = {
        -- Semantic search settings
        search = {
          prompt_title = "🤖 Claude Semantic Search",
          preview_title = "Context",
          results_title = "Results",
        },
        
        -- Command palette settings
        commands = {
          prompt_title = "🤖 Claude Commands",
          include_descriptions = true,
          show_keymaps = true,
        },
      }
      return opts
    end,
    config = function(_, opts)
      require("telescope").setup(opts)
      require("telescope").load_extension("claude_code")
    end,
  },
  
  -- Which-key integration
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      -- Automatically register Claude Code keybindings
      opts.defaults = opts.defaults or {}
      opts.defaults["<leader>c"] = { name = "🤖 Claude Code" }
      return opts
    end,
  },
}