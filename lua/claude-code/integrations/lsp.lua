-- LSP integration for claude-code.nvim
local M = {}

-- Setup LSP integration
function M.setup(opts)
  opts = opts or {}
  
  if opts.code_actions ~= false then
    M.setup_code_actions()
  end
  
  if opts.hover ~= false then
    M.setup_hover()
  end
  
  -- Set up autocmd for LSP attach
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('ClaudeCodeLSP', { clear = true }),
    callback = function(ev)
      M._on_lsp_attach(ev.buf)
    end,
  })
end

-- Add AI-powered code actions
function M.setup_code_actions()
  -- Store original function
  M._original_code_action = vim.lsp.buf.code_action
  
  -- Override code action
  vim.lsp.buf.code_action = function()
    local params = vim.lsp.util.make_range_params()
    params.context = {
      diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
      only = nil,
    }
    
    -- Get standard LSP code actions
    vim.lsp.buf_request_all(0, 'textDocument/codeAction', params, function(results)
      local actions = {}
      
      -- Collect LSP actions
      for client_id, result in pairs(results) do
        if result.result then
          for _, action in ipairs(result.result) do
            action.client_id = client_id
            table.insert(actions, action)
          end
        end
      end
      
      -- Add Claude Code actions
      local claude_actions = M._get_claude_actions()
      vim.list_extend(actions, claude_actions)
      
      -- Show actions with vim.ui.select
      if #actions == 0 then
        vim.notify('No code actions available', vim.log.levels.INFO)
        return
      end
      
      vim.ui.select(actions, {
        prompt = 'Code actions:',
        format_item = function(action)
          return action.title
        end,
      }, function(action)
        if not action then return end
        
        if action.is_claude then
          -- Handle Claude Code action
          M._execute_claude_action(action)
        else
          -- Handle LSP action
          local client = vim.lsp.get_client_by_id(action.client_id)
          if client then
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
            end
            if action.command then
              vim.lsp.buf.execute_command(action.command)
            end
          end
        end
      end)
    end)
  end
end

-- Get Claude Code actions
function M._get_claude_actions()
  local actions = {
    {
      title = "🤖 Explain this code",
      is_claude = true,
      action = "explain",
    },
    {
      title = "🤖 Add documentation",
      is_claude = true,
      action = "document",
    },
    {
      title = "🤖 Write tests",
      is_claude = true,
      action = "test",
    },
    {
      title = "🤖 Optimize performance",
      is_claude = true,
      action = "optimize",
    },
    {
      title = "🤖 Fix all issues",
      is_claude = true,
      action = "fix",
    },
    {
      title = "🤖 Refactor code",
      is_claude = true,
      action = "refactor",
    },
    {
      title = "🤖 Add error handling",
      is_claude = true,
      action = "error_handling",
    },
    {
      title = "🤖 Convert to async",
      is_claude = true,
      action = "async",
    },
  }
  
  -- Add context-specific actions based on diagnostics
  local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line('.') - 1 })
  if #diagnostics > 0 then
    table.insert(actions, 1, {
      title = "🤖 Fix diagnostics on this line",
      is_claude = true,
      action = "fix_line",
      diagnostics = diagnostics,
    })
  end
  
  return actions
end

-- Execute Claude Code action
function M._execute_claude_action(action)
  local context = require('claude-code.context').gather_context({
    type = action.action,
  })
  
  if action.action == "explain" then
    require('claude-code.actions').send_request({
      type = 'explain',
      context = context,
    }, function(response)
      if response.explanation then
        M._show_explanation(response.explanation)
      end
    end)
    
  elseif action.action == "document" then
    local selection = M._get_current_symbol()
    require('claude-code.actions').send_request({
      type = 'add_documentation',
      code = selection.text,
      language = vim.bo.filetype,
      context = context,
    }, function(response)
      if response.documentation then
        M._apply_documentation(response.documentation, selection)
      end
    end)
    
  elseif action.action == "test" then
    require('claude-code.actions').send_request({
      type = 'generate_tests',
      context = context,
    }, function(response)
      if response.tests then
        M._create_test_file(response.tests)
      end
    end)
    
  elseif action.action == "fix_line" then
    require('claude-code.actions').send_request({
      type = 'fix_diagnostics',
      diagnostics = action.diagnostics,
      context = context,
    }, function(response)
      if response.fixes then
        require('claude-code.ui.diff_preview').show(response.fixes)
      end
    end)
    
  else
    -- Generic action
    require('claude-code.ui.chat').open(
      string.format("Please %s the selected code", action.action:gsub("_", " "))
    )
  end
end

-- Enhanced hover with AI explanations
function M.setup_hover()
  -- Create a custom hover handler
  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    config = config or {}
    config.focus_id = ctx.method
    
    if not (result and result.contents) then
      return
    end
    
    -- Convert to markdown lines
    local contents = result.contents
    if type(contents) == 'string' then
      contents = { contents }
    elseif contents.kind == 'markdown' then
      contents = vim.split(contents.value, '\n')
    elseif contents.kind == 'plaintext' then
      contents = vim.split(contents.value, '\n')
    else
      contents = { tostring(contents) }
    end
    
    -- Add Claude Code action hint
    table.insert(contents, '')
    table.insert(contents, '---')
    table.insert(contents, '_Press `K` again for AI explanation_')
    
    -- Show hover window
    local bufnr, winnr = vim.lsp.util.open_floating_preview(
      contents,
      'markdown',
      config
    )
    
    -- Set up keymap in hover window
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '', {
      callback = function()
        vim.api.nvim_win_close(winnr, true)
        M._show_ai_hover()
      end,
      noremap = true,
      silent = true,
    })
    
    return bufnr, winnr
  end
end

-- Show AI hover explanation
function M._show_ai_hover()
  local word = vim.fn.expand('<cword>')
  local line = vim.api.nvim_get_current_line()
  
  require('claude-code.actions').send_request({
    type = 'explain_symbol',
    symbol = word,
    line = line,
    filetype = vim.bo.filetype,
  }, function(response)
    if response.explanation then
      M._show_explanation(response.explanation)
    end
  end)
end

-- Show explanation in floating window
function M._show_explanation(explanation)
  local lines = vim.split(explanation, '\n')
  
  -- Add formatting
  table.insert(lines, 1, '# AI Explanation')
  table.insert(lines, 2, '')
  
  local bufnr, winnr = vim.lsp.util.open_floating_preview(
    lines,
    'markdown',
    {
      focus = true,
      border = 'rounded',
      max_width = 80,
      max_height = 30,
    }
  )
  
  -- Make it easy to close
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
    end,
    noremap = true,
    silent = true,
  })
end

-- Get current symbol/function
function M._get_current_symbol()
  -- Try to get function/class using treesitter
  local node = vim.treesitter.get_node()
  
  while node do
    local type = node:type()
    if type == 'function_declaration' or 
       type == 'method_declaration' or
       type == 'class_declaration' or
       type == 'function_definition' then
      local start_row, start_col, end_row, end_col = node:range()
      local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
      
      -- Adjust for partial last line
      if #lines > 0 then
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
      if #lines > 0 and start_row == end_row then
        lines[1] = string.sub(lines[1], start_col + 1)
      elseif #lines > 0 then
        lines[1] = string.sub(lines[1], start_col + 1)
      end
      
      return {
        text = table.concat(lines, '\n'),
        start_line = start_row + 1,
        end_line = end_row + 1,
        node = node,
      }
    end
    node = node:parent()
  end
  
  -- Fallback to current line
  local line_num = vim.fn.line('.')
  return {
    text = vim.api.nvim_get_current_line(),
    start_line = line_num,
    end_line = line_num,
  }
end

-- Apply documentation to code
function M._apply_documentation(documentation, selection)
  -- TODO: Smart insertion of documentation based on language
  local lines = vim.split(documentation, '\n')
  
  -- Insert before the selection
  vim.api.nvim_buf_set_lines(
    0,
    selection.start_line - 1,
    selection.start_line - 1,
    false,
    lines
  )
  
  vim.notify("Documentation added", vim.log.levels.INFO)
end

-- Create test file
function M._create_test_file(tests)
  -- Determine test file name
  local current_file = vim.api.nvim_buf_get_name(0)
  local test_file = M._get_test_filename(current_file)
  
  -- Check if test file exists
  if vim.fn.filereadable(test_file) == 1 then
    vim.ui.select({'Append', 'Replace', 'Cancel'}, {
      prompt = 'Test file exists. Action:',
    }, function(choice)
      if choice == 'Append' then
        vim.cmd('edit ' .. test_file)
        vim.cmd('normal! G')
        vim.api.nvim_put(vim.split(tests, '\n'), 'l', true, true)
      elseif choice == 'Replace' then
        vim.cmd('edit ' .. test_file)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(tests, '\n'))
      end
    end)
  else
    -- Create new test file
    vim.cmd('edit ' .. test_file)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(tests, '\n'))
    vim.notify("Test file created: " .. test_file, vim.log.levels.INFO)
  end
end

-- Get test filename
function M._get_test_filename(file)
  local base = vim.fn.fnamemodify(file, ':r')
  local ext = vim.fn.fnamemodify(file, ':e')
  
  -- Common test file patterns
  if vim.bo.filetype == 'javascript' or vim.bo.filetype == 'typescript' then
    return base .. '.test.' .. ext
  elseif vim.bo.filetype == 'python' then
    return 'test_' .. vim.fn.fnamemodify(file, ':t')
  elseif vim.bo.filetype == 'go' then
    return base .. '_test.' .. ext
  else
    return base .. '_test.' .. ext
  end
end

-- On LSP attach
function M._on_lsp_attach(bufnr)
  -- Add buffer-local keymaps for Claude Code actions
  local opts = { buffer = bufnr, silent = true }
  
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, 
    vim.tbl_extend('force', opts, { desc = 'Code actions (with AI)' }))
end

return M