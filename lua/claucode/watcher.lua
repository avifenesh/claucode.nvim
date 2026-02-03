local M = {}

local uv = vim.loop
local watchers = {}
local file_timestamps = {}
local debounce_timers = {}
local is_running = false

local function should_ignore(path, patterns)
  for _, pattern in ipairs(patterns) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

local function get_file_mtime(path)
  local stat = uv.fs_stat(path)
  return stat and stat.mtime.sec or nil
end

local function is_binary_file(filepath)
  -- Check file extension for known binary types
  local binary_extensions = {
    "%.class$", "%.jar$", "%.war$", "%.ear$",
    "%.pyc$", "%.pyo$", "%.pyd$",
    "%.exe$", "%.dll$", "%.so$", "%.dylib$",
    "%.o$", "%.a$", "%.lib$",
    "%.pdf$", "%.jpg$", "%.jpeg$", "%.png$", "%.gif$", "%.bmp$", "%.ico$", "%.webp$",
    "%.mp3$", "%.mp4$", "%.avi$", "%.mov$",
    "%.zip$", "%.tar$", "%.gz$", "%.rar$", "%.7z$",
    "%.db$", "%.sqlite$", "%.sqlite3$",
  }
  
  for _, pattern in ipairs(binary_extensions) do
    if filepath:match(pattern) then
      return true
    end
  end
  
  return false
end

local function reload_buffer_if_changed(filepath)
  vim.schedule(function()
    -- Skip binary files
    if is_binary_file(filepath) then
      return
    end
    
    -- Find all buffers with this file
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name == filepath then
          -- Check if buffer has unsaved changes using modern vim.bo API
          local modified = vim.bo[buf].modified
          
          if not modified then
            -- Reload the buffer
            vim.api.nvim_buf_call(buf, function()
              vim.cmd("edit!")
            end)
            local notify = require("claucode.notify")
            notify.buffer_reload("Reloaded: " .. vim.fn.fnamemodify(filepath, ":~:."))
          else
            -- Notify user about conflict (always show warnings)
            local notify = require("claucode.notify")
            notify.warn(
              "File changed externally but buffer has unsaved changes: " ..
              vim.fn.fnamemodify(filepath, ":~:.")
            )
          end
          break
        end
      end
    end
  end)
end

local function handle_file_change(filepath, config)
  -- Debounce file changes
  if debounce_timers[filepath] then
    uv.timer_stop(debounce_timers[filepath])
    uv.close(debounce_timers[filepath])
  end
  
  debounce_timers[filepath] = uv.new_timer()
  debounce_timers[filepath]:start(config.watcher.debounce, 0, function()
    vim.schedule(function()
      uv.timer_stop(debounce_timers[filepath])
      uv.close(debounce_timers[filepath])
      debounce_timers[filepath] = nil
      
      -- Check if file was actually modified
      local current_mtime = get_file_mtime(filepath)
      local last_mtime = file_timestamps[filepath]
      
      if current_mtime and current_mtime ~= last_mtime then
        file_timestamps[filepath] = current_mtime
        reload_buffer_if_changed(filepath)
      end
    end)
  end)
end

local function watch_file(filepath, config)
  if watchers[filepath] then
    return -- Already watching
  end
  
  local handle = uv.new_fs_event()
  local ok, err = pcall(function()
    handle:start(filepath, {}, function(err, filename, events)
      if err then
        vim.schedule(function()
          local notify = require("claucode.notify")
          notify.error("File watcher error: " .. err)
        end)
        return
      end
      
      if events.change then
        handle_file_change(filepath, config)
      end
    end)
  end)
  
  if ok then
    watchers[filepath] = handle
    file_timestamps[filepath] = get_file_mtime(filepath)
  else
    vim.schedule(function()
      local notify = require("claucode.notify")
      notify.error("Failed to watch file: " .. filepath .. " - " .. err)
    end)
  end
end

local function watch_directory(dirpath, config)
  local handle = uv.new_fs_event()
  local ok, err = pcall(function()
    handle:start(dirpath, {}, function(err, filename, events)
      if err then
        vim.schedule(function()
          local notify = require("claucode.notify")
          notify.error("Directory watcher error: " .. err)
        end)
        return
      end
      
      if filename then
        local filepath = dirpath .. "/" .. filename
        
        -- Check if we should ignore this file
        if not should_ignore(filepath, config.watcher.ignore_patterns) then
          if events.change then
            -- Start watching the file if we aren't already
            watch_file(filepath, config)
            handle_file_change(filepath, config)
          end
        end
      end
    end)
  end)
  
  if ok then
    watchers[dirpath] = handle
  else
    vim.schedule(function()
      local notify = require("claucode.notify")
      notify.error("Failed to watch directory: " .. dirpath .. " - " .. err)
    end)
  end
end

function M.start(config)
  if is_running then
    return
  end
  
  is_running = true
  
  -- Watch the current working directory
  local cwd = vim.fn.getcwd()
  watch_directory(cwd, config)
  
  -- Also watch all currently open buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local filepath = vim.api.nvim_buf_get_name(buf)
      if filepath ~= "" and not should_ignore(filepath, config.watcher.ignore_patterns) then
        watch_file(filepath, config)
      end
    end
  end
  
  -- Watch new buffers as they're opened
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("ClauCodeWatcher", { clear = true }),
    callback = function(args)
      local filepath = args.file
      if filepath ~= "" and not should_ignore(filepath, config.watcher.ignore_patterns) then
        watch_file(filepath, config)
      end
    end,
  })

  local notify = require("claucode.notify")
  notify.watcher("Claude Code file watcher started")
end

function M.stop()
  if not is_running then
    return
  end
  
  is_running = false
  
  -- Stop all watchers
  for path, handle in pairs(watchers) do
    if handle then
      handle:stop()
      uv.close(handle)
    end
  end
  watchers = {}
  
  -- Clear debounce timers
  for path, timer in pairs(debounce_timers) do
    if timer then
      uv.timer_stop(timer)
      uv.close(timer)
    end
  end
  debounce_timers = {}
  
  -- Clear autocmd
  pcall(vim.api.nvim_del_augroup_by_name, "ClauCodeWatcher")

  local notify = require("claucode.notify")
  notify.watcher("Claude Code file watcher stopped")
end

function M.is_running()
  return is_running
end

return M