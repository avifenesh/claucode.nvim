local M = {}

local changed_files = {}
local diff_cache = {}

local function get_git_diff(filepath)
  -- Try to get git diff for the file
  local cmd = string.format("git diff --no-index --no-prefix /dev/null %s 2>/dev/null || git diff --no-prefix %s 2>/dev/null", 
    vim.fn.shellescape(filepath), vim.fn.shellescape(filepath))
  local diff = vim.fn.system(cmd)
  
  if vim.v.shell_error == 0 and diff ~= "" then
    return diff
  end
  
  -- If git diff fails, create a simple diff showing the file content
  local content = vim.fn.readfile(filepath)
  if #content > 0 then
    local lines = {
      "--- " .. filepath,
      "+++ " .. filepath,
      "@@ -0,0 +1," .. #content .. " @@",
    }
    for _, line in ipairs(content) do
      table.insert(lines, "+" .. line)
    end
    return table.concat(lines, "\n")
  end
  
  return nil
end

local function create_diff_buffer(filepath)
  local diff = diff_cache[filepath] or get_git_diff(filepath)
  if not diff then
    vim.notify("No changes found for: " .. filepath, vim.log.levels.WARN)
    return nil
  end
  
  -- Cache the diff
  diff_cache[filepath] = diff
  
  -- Create a new buffer for the diff
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Set buffer content
  local lines = vim.split(diff, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, "Claude Changes: " .. vim.fn.fnamemodify(filepath, ":t"))
  
  return buf
end

function M.add_changed_file(filepath)
  -- Normalize the filepath
  filepath = vim.fn.fnamemodify(filepath, ":p")
  
  -- Add to changed files if not already present
  local already_tracked = false
  for _, f in ipairs(changed_files) do
    if f == filepath then
      already_tracked = true
      break
    end
  end
  
  if not already_tracked then
    table.insert(changed_files, filepath)
    -- Clear cached diff as file has changed
    diff_cache[filepath] = nil
  end
end

function M.show_pending_changes()
  if #changed_files == 0 then
    vim.notify("No pending changes from Claude", vim.log.levels.INFO)
    return
  end
  
  local config = require("claucode").get_config()
  local ui_config = config.ui.diff
  
  -- Create a floating window to show the list of changed files
  local width = math.floor(vim.o.columns * ui_config.width)
  local height = math.floor(vim.o.lines * ui_config.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create buffer for file list
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(list_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(list_buf, "bufhidden", "wipe")
  
  -- Prepare content
  local lines = { "Claude Code - Changed Files:", "" }
  for i, filepath in ipairs(changed_files) do
    table.insert(lines, string.format("%d. %s", i, vim.fn.fnamemodify(filepath, ":~:.")))
  end
  table.insert(lines, "")
  table.insert(lines, "Press <Enter> to view diff, 'a' to accept, 'r' to reject, 'q' to quit")
  
  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(list_buf, "modifiable", false)
  
  -- Create window
  local win = vim.api.nvim_open_win(list_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = ui_config.border,
    title = " Claude Code Review ",
    title_pos = "center",
  })
  
  -- Highlight current line
  vim.api.nvim_win_set_option(win, "cursorline", true)
  vim.api.nvim_win_set_cursor(win, {3, 0}) -- Start at first file
  
  -- Set up keymaps for the review window
  local function get_current_file_index()
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local index = line - 2
    if index >= 1 and index <= #changed_files then
      return index
    end
    return nil
  end
  
  -- Enter to view diff
  vim.keymap.set("n", "<CR>", function()
    local index = get_current_file_index()
    if index then
      local filepath = changed_files[index]
      local diff_buf = create_diff_buffer(filepath)
      if diff_buf then
        -- Open diff in a split
        vim.cmd("vsplit")
        vim.api.nvim_win_set_buf(0, diff_buf)
      end
    end
  end, { buffer = list_buf })
  
  -- 'a' to accept changes (reload file)
  vim.keymap.set("n", "a", function()
    local index = get_current_file_index()
    if index then
      local filepath = changed_files[index]
      -- Force reload the file in any open buffers
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == filepath then
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("edit!")
          end)
        end
      end
      -- Remove from changed files
      table.remove(changed_files, index)
      diff_cache[filepath] = nil
      -- Update display
      M.show_pending_changes()
    end
  end, { buffer = list_buf })
  
  -- 'r' to reject changes (restore from git or delete)
  vim.keymap.set("n", "r", function()
    local index = get_current_file_index()
    if index then
      local filepath = changed_files[index]
      local choice = vim.fn.confirm("Reject changes to " .. vim.fn.fnamemodify(filepath, ":t") .. "?", "&Yes\n&No", 2)
      if choice == 1 then
        -- Try to restore from git
        local cmd = "git checkout -- " .. vim.fn.shellescape(filepath)
        local result = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          vim.notify("Failed to restore file from git: " .. result, vim.log.levels.ERROR)
        else
          vim.notify("Restored: " .. filepath, vim.log.levels.INFO)
          -- Remove from changed files
          table.remove(changed_files, index)
          diff_cache[filepath] = nil
          -- Update display
          M.show_pending_changes()
        end
      end
    end
  end, { buffer = list_buf })
  
  -- 'q' to quit
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = list_buf })
  
  -- Clear changes on window close
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = list_buf,
    once = true,
    callback = function()
      -- Clean up
    end,
  })
end

function M.clear_changes()
  changed_files = {}
  diff_cache = {}
end

function M.get_pending_changes_count()
  return #changed_files
end

return M