local M = {}
local config = require('claude-code.config')

-- Context types for smart gathering
M.context_types = {
  refactor = {
    include_tests = true,
    include_related = true,
    include_interfaces = true,
    max_depth = 2,
  },
  debug = {
    include_errors = true,
    include_logs = true,
    include_stack_trace = true,
    include_recent_changes = true,
  },
  implement = {
    include_interfaces = true,
    include_types = true,
    include_examples = true,
    include_docs = true,
  },
  test = {
    include_source = true,
    include_existing_tests = true,
    include_test_utils = true,
    include_fixtures = true,
  },
  document = {
    include_types = true,
    include_usage = true,
    include_related_docs = true,
  },
  review = {
    include_git_diff = true,
    include_recent_commits = true,
    include_related_files = true,
  },
}

function M.gather_context(opts)
  opts = opts or {}
  
  -- Determine context type from task
  local context_type = M._determine_context_type(opts.task_type or opts.type)
  local type_config = M.context_types[context_type] or {}
  
  local context = {
    buffers = {},
    current_file = vim.api.nvim_buf_get_name(0),
    cursor_position = vim.api.nvim_win_get_cursor(0),
    filetype = vim.bo.filetype,
    project_root = M.find_project_root(),
    type = context_type,
  }
  
  -- Get current buffer content
  local current_buf = vim.api.nvim_get_current_buf()
  context.current_buffer = {
    id = current_buf,
    content = table.concat(vim.api.nvim_buf_get_lines(current_buf, 0, -1, false), '\n'),
    name = vim.api.nvim_buf_get_name(current_buf),
    filetype = vim.bo[current_buf].filetype,
  }
  
  -- Get visual selection if in visual mode
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' then
    context.selection = M.get_visual_selection()
  end
  
  -- Get other open buffers if requested
  if opts.include_buffers then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and buf ~= current_buf then
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= '' then
          table.insert(context.buffers, {
            id = buf,
            name = name,
            filetype = vim.bo[buf].filetype,
          })
        end
      end
    end
  end
  
  -- Get LSP information
  context.lsp = M.get_lsp_context()
  
  -- Smart context gathering based on type
  if type_config.include_tests then
    context.test_files = M._find_test_files(context.current_file)
  end
  
  if type_config.include_errors then
    context.diagnostics = M._get_diagnostics()
  end
  
  if type_config.include_git_diff then
    context.git_diff = M._get_git_diff()
  end
  
  if type_config.include_related then
    context.related_files = M._find_related_files(context.current_file)
  end
  
  if type_config.include_interfaces then
    context.interfaces = M._find_interfaces()
  end
  
  if type_config.include_recent_changes then
    context.recent_changes = M._get_recent_changes()
  end
  
  if type_config.include_types then
    context.type_definitions = M._find_type_definitions()
  end
  
  return context
end

-- Determine context type from task
function M._determine_context_type(task)
  if not task then return "general" end
  
  task = task:lower()
  
  if task:match("refactor") or task:match("extract") or task:match("rename") then
    return "refactor"
  elseif task:match("debug") or task:match("fix") or task:match("error") then
    return "debug"
  elseif task:match("implement") or task:match("create") or task:match("add") then
    return "implement"
  elseif task:match("test") or task:match("spec") then
    return "test"
  elseif task:match("document") or task:match("docs") or task:match("comment") then
    return "document"
  elseif task:match("review") or task:match("pr") or task:match("commit") then
    return "review"
  else
    return "general"
  end
end

-- Find test files related to current file
function M._find_test_files(file)
  local test_files = {}
  local base_name = vim.fn.fnamemodify(file, ':t:r')
  local dir = vim.fn.fnamemodify(file, ':h')
  
  -- Common test patterns
  local patterns = {
    base_name .. "_test.*",
    base_name .. "_spec.*",
    base_name .. ".test.*",
    base_name .. ".spec.*",
    "test_" .. base_name .. ".*",
  }
  
  -- Look in common test directories
  local test_dirs = { dir, dir .. "/__tests__", dir .. "/../test", dir .. "/../tests" }
  
  for _, test_dir in ipairs(test_dirs) do
    if vim.fn.isdirectory(test_dir) == 1 then
      for _, pattern in ipairs(patterns) do
        local files = vim.fn.glob(test_dir .. "/" .. pattern, false, true)
        vim.list_extend(test_files, files)
      end
    end
  end
  
  return test_files
end

-- Get current diagnostics
function M._get_diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  local formatted = {}
  
  for _, diag in ipairs(diagnostics) do
    table.insert(formatted, {
      line = diag.lnum + 1,
      col = diag.col + 1,
      severity = diag.severity,
      message = diag.message,
      source = diag.source,
    })
  end
  
  return formatted
end

-- Get git diff
function M._get_git_diff()
  local diff = vim.fn.system("git diff --cached")
  if vim.v.shell_error == 0 then
    return diff
  end
  return nil
end

-- Find related files
function M._find_related_files(file)
  local related = {}
  local base_name = vim.fn.fnamemodify(file, ':t:r')
  local ext = vim.fn.fnamemodify(file, ':e')
  
  -- Look for files with similar names
  local cmd = string.format("find . -name '*%s*' -type f | head -20", base_name)
  local files = vim.fn.systemlist(cmd)
  
  for _, f in ipairs(files) do
    if f ~= file then
      table.insert(related, f)
    end
  end
  
  return related
end

-- Find interfaces/protocols
function M._find_interfaces()
  local interfaces = {}
  
  -- Use LSP to find interfaces
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }
  
  local results = vim.lsp.buf_request_sync(0, 'textDocument/typeDefinition', params, 1000)
  
  for _, result in pairs(results or {}) do
    if result.result then
      for _, location in ipairs(result.result) do
        table.insert(interfaces, {
          uri = location.uri,
          range = location.range,
        })
      end
    end
  end
  
  return interfaces
end

-- Get recent changes
function M._get_recent_changes()
  local changes = {}
  
  -- Get recent commits affecting current file
  local file = vim.api.nvim_buf_get_name(0)
  local cmd = string.format("git log -5 --oneline -- %s", vim.fn.shellescape(file))
  local commits = vim.fn.systemlist(cmd)
  
  if vim.v.shell_error == 0 then
    changes.commits = commits
  end
  
  -- Get uncommitted changes
  local diff = vim.fn.system(string.format("git diff -- %s", vim.fn.shellescape(file)))
  if vim.v.shell_error == 0 and diff ~= "" then
    changes.uncommitted = diff
  end
  
  return changes
end

-- Find type definitions
function M._find_type_definitions()
  local types = {}
  
  -- Use treesitter to find type definitions
  local ok, parser = pcall(vim.treesitter.get_parser)
  if ok and parser then
    local tree = parser:parse()[1]
    local root = tree:root()
    
    local query = vim.treesitter.query.parse(vim.bo.filetype, [[
      (type_definition) @type
      (interface_declaration) @interface
      (class_declaration) @class
    ]])
    
    for id, node in query:iter_captures(root, 0) do
      local name = query.captures[id]
      local text = vim.treesitter.get_node_text(node, 0)
      table.insert(types, {
        type = name,
        text = text,
      })
    end
  end
  
  return types
end

function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 0 then
    return nil
  end
  
  -- Handle partial line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end
  
  return {
    text = table.concat(lines, '\n'),
    start_line = start_pos[2],
    end_line = end_pos[2],
  }
end

function M.find_project_root()
  local patterns = {'.git', 'package.json', 'Cargo.toml', 'go.mod', 'pyproject.toml'}
  local path = vim.fn.expand('%:p:h')
  
  while path ~= '/' do
    for _, pattern in ipairs(patterns) do
      if vim.fn.isdirectory(path .. '/' .. pattern) == 1 or 
         vim.fn.filereadable(path .. '/' .. pattern) == 1 then
        return path
      end
    end
    path = vim.fn.fnamemodify(path, ':h')
  end
  
  return vim.fn.getcwd()
end

function M.get_lsp_context()
  local clients = vim.lsp.get_active_clients({bufnr = 0})
  local context = {
    active_clients = {},
    workspace_folders = {},
  }
  
  for _, client in ipairs(clients) do
    table.insert(context.active_clients, {
      name = client.name,
      id = client.id,
    })
    
    if client.config.workspace_folders then
      for _, folder in ipairs(client.config.workspace_folders) do
        table.insert(context.workspace_folders, folder.name)
      end
    end
  end
  
  return context
end

function M.show_current()
  local context = M.gather_context({include_buffers = true})
  local lines = {
    "Claude Code Context:",
    "",
    "Current File: " .. context.current_file,
    "Filetype: " .. context.filetype,
    "Project Root: " .. context.project_root,
    "Cursor Position: " .. context.cursor_position[1] .. "," .. context.cursor_position[2],
    "",
    "Open Buffers: " .. #context.buffers,
  }
  
  if #context.lsp.active_clients > 0 then
    table.insert(lines, "")
    table.insert(lines, "LSP Clients:")
    for _, client in ipairs(context.lsp.active_clients) do
      table.insert(lines, "  - " .. client.name)
    end
  end
  
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M