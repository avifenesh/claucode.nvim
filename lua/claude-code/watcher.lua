-- File watcher for Claude Code changes
local M = {}
local uv = vim.loop

M.config = {}
M.watchers = {}
M.file_versions = {}

function M.setup(config)
  M.config = config
  
  if not config.watcher.enabled then
    return
  end
  
  -- Watch project root
  M.watch_directory(vim.fn.getcwd())
  
  -- Watch shared directory for Claude's responses
  M.watch_shared_dir()
  
  -- Set up autocommands
  M._setup_autocommands()
end

-- Watch a directory for changes
function M.watch_directory(path)
  if M.watchers[path] then
    return
  end
  
  local watcher = uv.new_fs_event()
  local recursive = true
  
  local function on_change(err, filename, events)
    if err then
      vim.notify("File watcher error: " .. err, vim.log.levels.ERROR)
      return
    end
    
    -- Handle the change
    vim.schedule(function()
      M._handle_file_change(path .. '/' .. filename, events)
    end)
  end
  
  watcher:start(path, {
    recursive = recursive
  }, on_change)
  
  M.watchers[path] = watcher
end

-- Watch shared directory for Claude's updates
function M.watch_shared_dir()
  local shared_dir = M.config.bridge.shared_dir
  local changes_file = shared_dir .. '/changes.json'
  
  -- Poll for changes (more reliable than fs events for single files)
  local timer = uv.new_timer()
  timer:start(1000, 1000, vim.schedule_wrap(function()
    M._check_for_claude_changes(changes_file)
  end))
  
  M.watchers.shared_timer = timer
end

-- Check for changes from Claude
function M._check_for_claude_changes(changes_file)
  if vim.fn.filereadable(changes_file) == 0 then
    return
  end
  
  local mtime = vim.fn.getftime(changes_file)
  if M.file_versions[changes_file] == mtime then
    return
  end
  
  M.file_versions[changes_file] = mtime
  
  -- Read and process changes
  local content = vim.fn.readfile(changes_file)
  if #content > 0 then
    local ok, changes = pcall(vim.json.decode, content[1])
    if ok and changes.files then
      M._process_claude_changes(changes)
      -- Clear the file after processing
      vim.fn.writefile({''}, changes_file)
    end
  end
end

-- Process changes from Claude
function M._process_claude_changes(changes)
  local affected_buffers = {}
  
  for _, change in ipairs(changes.files or {}) do
    -- Find buffer for this file
    local bufnr = vim.fn.bufnr(change.path)
    
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      affected_buffers[bufnr] = change
    end
    
    -- Track file version
    M.file_versions[change.path] = vim.fn.getftime(change.path)
  end
  
  -- Handle affected buffers
  for bufnr, change in pairs(affected_buffers) do
    M._handle_buffer_change(bufnr, change)
  end
  
  -- Show review if configured
  if M.config.watcher.diff_preview and next(affected_buffers) then
    require('claude-code.review').show_changes(changes)
  end
end

-- Handle file change
function M._handle_file_change(filepath, events)
  -- Skip if this is our own change
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr == -1 then
    return
  end
  
  -- Check if file was modified externally
  local current_mtime = vim.fn.getftime(filepath)
  local last_mtime = M.file_versions[filepath] or 0
  
  if current_mtime > last_mtime then
    M.file_versions[filepath] = current_mtime
    
    -- Check if buffer needs reloading
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local modified = vim.bo[bufnr].modified
      
      if not modified and M.config.watcher.auto_reload then
        -- Auto reload
        vim.schedule(function()
          vim.cmd('checktime ' .. bufnr)
          vim.notify("Claude updated: " .. vim.fn.fnamemodify(filepath, ':~:.'), vim.log.levels.INFO)
        end)
      else
        -- Notify user
        vim.notify("Claude modified: " .. vim.fn.fnamemodify(filepath, ':~:.') .. " (use :checktime to reload)", vim.log.levels.WARN)
      end
    end
  end
end

-- Handle buffer change
function M._handle_buffer_change(bufnr, change)
  if change.action == 'modify' then
    if M.config.watcher.auto_reload and not vim.bo[bufnr].modified then
      -- Reload the buffer
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd('edit!')
      end)
      vim.notify("Reloaded: " .. vim.fn.fnamemodify(change.path, ':~:.'), vim.log.levels.INFO)
    else
      -- Show diff preview
      if M.config.watcher.diff_preview then
        require('claude-code.review').preview_file_changes(bufnr, change)
      end
    end
  end
end

-- Set up autocommands
function M._setup_autocommands()
  local group = vim.api.nvim_create_augroup('ClaudeCodeWatcher', { clear = true })
  
  -- Track our own saves to avoid reload loops
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function(args)
      M.file_versions[args.file] = vim.fn.getftime(args.file)
    end,
  })
  
  -- Clean up watchers on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.stop_all()
    end,
  })
end

-- Stop all watchers
function M.stop_all()
  for path, watcher in pairs(M.watchers) do
    if type(watcher) == 'userdata' then
      if watcher.stop then
        watcher:stop()
      end
      if watcher.close then
        watcher:close()
      end
    end
  end
  M.watchers = {}
end

return M