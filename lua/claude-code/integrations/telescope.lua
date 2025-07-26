-- Telescope integration for claude-code.nvim
local M = {}

-- Check if telescope is available
local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  return M
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local entry_display = require('telescope.pickers.entry_display')

-- Slash commands picker
M.slash_commands = function(opts)
  opts = opts or {}
  
  -- Get available commands
  local commands = {
    { name = "/add-dir", description = "Add additional working directories", category = "workspace" },
    { name = "/agents", description = "Manage custom AI sub agents", category = "ai" },
    { name = "/bug", description = "Report bugs to Anthropic", category = "help" },
    { name = "/clear", description = "Clear conversation history", category = "chat" },
    { name = "/compact", description = "Compact conversation with optional focus", category = "chat" },
    { name = "/config", description = "View/modify configuration", category = "settings" },
    { name = "/cost", description = "Show token usage statistics", category = "usage" },
    { name = "/doctor", description = "Check Claude Code installation health", category = "help" },
    { name = "/help", description = "Get usage help", category = "help" },
    { name = "/init", description = "Initialize project with CLAUDE.md guide", category = "project" },
    { name = "/login", description = "Switch Anthropic accounts", category = "auth" },
    { name = "/logout", description = "Sign out from Anthropic account", category = "auth" },
    { name = "/mcp", description = "Manage MCP server connections", category = "integrations" },
    { name = "/memory", description = "Edit CLAUDE.md memory files", category = "project" },
    { name = "/model", description = "Select or change AI model", category = "ai" },
    { name = "/permissions", description = "View or update permissions", category = "settings" },
    { name = "/pr_comments", description = "View pull request comments", category = "git" },
    { name = "/review", description = "Request code review", category = "code" },
    { name = "/status", description = "View account and system statuses", category = "info" },
    { name = "/terminal-setup", description = "Install key binding for newlines", category = "setup" },
    { name = "/vim", description = "Enter vim mode", category = "editor" },
  }
  
  -- Add custom commands if available
  local custom_commands = require('claude-code.commands').get_custom_commands()
  for _, cmd in ipairs(custom_commands) do
    table.insert(commands, cmd)
  end
  
  -- Create displayer
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 20 },
      { width = 10 },
      { remaining = true },
    },
  })
  
  local make_display = function(entry)
    return displayer({
      { entry.value.name, "TelescopeResultsIdentifier" },
      { "[" .. entry.value.category .. "]", "TelescopeResultsComment" },
      { entry.value.description, "TelescopeResultsString" },
    })
  end
  
  pickers.new(opts, {
    prompt_title = "Claude Code Commands",
    finder = finders.new_table({
      results = commands,
      entry_maker = function(entry)
        return {
          value = entry,
          display = make_display,
          ordinal = entry.name .. " " .. entry.description,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Command Help",
      define_preview = function(self, entry)
        local command = entry.value
        local lines = {
          "Command: " .. command.name,
          "",
          "Description: " .. command.description,
          "",
          "Category: " .. command.category,
          "",
        }
        
        -- Add usage examples if available
        if command.usage then
          table.insert(lines, "Usage:")
          table.insert(lines, "  " .. command.usage)
          table.insert(lines, "")
        end
        
        -- Add additional help if available
        if command.help then
          table.insert(lines, "Help:")
          for _, line in ipairs(vim.split(command.help, '\n')) do
            table.insert(lines, "  " .. line)
          end
        end
        
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          -- Execute the command
          vim.cmd('ClaudeCode ' .. selection.value.name:sub(2)) -- Remove leading /
        end
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
    if not query or query == '' then return end
    
    -- Show loading indicator
    vim.notify("Searching for: " .. query, vim.log.levels.INFO)
    
    require('claude-code.actions').semantic_search({
      query = query,
      project_root = opts.cwd or vim.fn.getcwd(),
      max_results = opts.max_results or 50,
    }, function(results)
      if not results or #results == 0 then
        vim.notify("No results found for: " .. query, vim.log.levels.WARN)
        return
      end
      
      -- Create displayer
      local displayer = entry_display.create({
        separator = " ",
        items = {
          { width = 40 },
          { width = 6 },
          { remaining = true },
        },
      })
      
      local make_display = function(entry)
        local file = vim.fn.fnamemodify(entry.value.file, ':.')
        return displayer({
          { file, "TelescopeResultsIdentifier" },
          { ":" .. entry.value.line, "TelescopeResultsNumber" },
          { entry.value.preview, "TelescopeResultsString" },
        })
      end
      
      pickers.new(opts, {
        prompt_title = 'Claude Code Search: ' .. query,
        finder = finders.new_table({
          results = results,
          entry_maker = function(entry)
            return {
              value = entry,
              display = make_display,
              ordinal = entry.file .. ' ' .. entry.content,
              filename = entry.file,
              lnum = entry.line,
              col = entry.col or 1,
            }
          end,
        }),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter(opts),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
      }):find()
    end)
  end)
end

-- AI agents picker
M.agents = function(opts)
  opts = opts or {}
  
  -- Get available agents
  local agents = require('claude-code.agents').get_available()
  
  pickers.new(opts, {
    prompt_title = "Claude Code Agents",
    finder = finders.new_table({
      results = agents,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name .. " - " .. entry.description,
          ordinal = entry.name .. " " .. entry.description,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Agent Details",
      define_preview = function(self, entry)
        local agent = entry.value
        local lines = {
          "Agent: " .. agent.name,
          "",
          "Description: " .. agent.description,
          "",
          "Capabilities:",
        }
        
        for _, capability in ipairs(agent.capabilities or {}) do
          table.insert(lines, "  • " .. capability)
        end
        
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          require('claude-code.agents').activate(selection.value.name)
        end
      end)
      return true
    end,
  }):find()
end

-- Templates picker
M.templates = function(opts)
  opts = opts or {}
  
  -- Get available templates
  local templates = require('claude-code.templates').get_all()
  
  -- Group templates by category
  local categories = {}
  for _, template in ipairs(templates) do
    local cat = template.category or "general"
    categories[cat] = categories[cat] or {}
    table.insert(categories[cat], template)
  end
  
  -- Flatten for display
  local items = {}
  for category, temps in pairs(categories) do
    for _, template in ipairs(temps) do
      table.insert(items, {
        name = template.name,
        description = template.description,
        category = category,
        content = template.content,
      })
    end
  end
  
  pickers.new(opts, {
    prompt_title = "Claude Code Templates",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("[%s] %s - %s", entry.category, entry.name, entry.description),
          ordinal = entry.name .. " " .. entry.description .. " " .. entry.category,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Template Preview",
      define_preview = function(self, entry)
        local lines = vim.split(entry.value.content, '\n')
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          require('claude-code.templates').use(selection.value.name)
        end
      end)
      return true
    end,
  }):find()
end

-- Register extension
function M.register()
  return telescope.register_extension({
    setup = function(ext_config, config)
      -- Extension setup
    end,
    exports = {
      claude_commands = M.slash_commands,
      claude_search = M.code_search,
      claude_agents = M.agents,
      claude_templates = M.templates,
      -- Shortcuts
      commands = M.slash_commands,
      search = M.code_search,
      agents = M.agents,
      templates = M.templates,
    },
  })
end

-- Auto-register if telescope is available
if has_telescope then
  M.register()
end

return M