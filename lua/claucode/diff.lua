local M = {}

local uv = vim.loop

-- Cache for storing pending diffs
local pending_diffs = {}

-- Generate a diff between the current file content and proposed changes
function M.generate_diff(filepath, new_content)
  -- Read current file content
  local current_lines = {}
  local file = io.open(filepath, "r")
  if file then
    for line in file:lines() do
      table.insert(current_lines, line)
    end
    file:close()
  end
  
  -- Split new content into lines
  local new_lines = vim.split(new_content, "\n", { plain = true })
  
  -- Generate unified diff format
  local diff_lines = {
    "--- " .. filepath,
    "+++ " .. filepath .. " (proposed)",
  }
  
  -- Simple line-by-line diff (for now)
  local max_lines = math.max(#current_lines, #new_lines)
  local in_change_block = false
  local change_start = 0
  local removed_lines = {}
  local added_lines = {}
  
  for i = 1, max_lines do
    local current = current_lines[i]
    local new = new_lines[i]
    
    if current ~= new then
      if not in_change_block then
        in_change_block = true
        change_start = i
        removed_lines = {}
        added_lines = {}
      end
      
      if current then
        table.insert(removed_lines, "-" .. current)
      end
      if new then
        table.insert(added_lines, "+" .. new)
      end
    else
      -- End of change block
      if in_change_block then
        -- Add hunk header
        local old_start = change_start
        local old_count = #removed_lines
        local new_start = change_start
        local new_count = #added_lines
        
        table.insert(diff_lines, string.format("@@ -%d,%d +%d,%d @@", 
          old_start, old_count > 0 and old_count or 1,
          new_start, new_count > 0 and new_count or 1))
        
        -- Add removed and added lines
        for _, line in ipairs(removed_lines) do
          table.insert(diff_lines, line)
        end
        for _, line in ipairs(added_lines) do
          table.insert(diff_lines, line)
        end
        
        in_change_block = false
      end
      
      -- Add context line if not at end
      if current and i < max_lines then
        table.insert(diff_lines, " " .. current)
      end
    end
  end
  
  -- Handle any remaining changes at end
  if in_change_block then
    local old_start = change_start
    local old_count = #removed_lines
    local new_start = change_start
    local new_count = #added_lines
    
    table.insert(diff_lines, string.format("@@ -%d,%d +%d,%d @@", 
      old_start, old_count > 0 and old_count or 1,
      new_start, new_count > 0 and new_count or 1))
    
    for _, line in ipairs(removed_lines) do
      table.insert(diff_lines, line)
    end
    for _, line in ipairs(added_lines) do
      table.insert(diff_lines, line)
    end
  end
  
  return table.concat(diff_lines, "\n")
end

-- Show diff in a floating window
function M.show_diff_preview(filepath, new_content, on_accept, on_reject)
  local diff = M.generate_diff(filepath, new_content)
  
  -- Store pending diff info
  pending_diffs[filepath] = {
    content = new_content,
    on_accept = on_accept,
    on_reject = on_reject,
  }
  
  -- Create buffer for diff
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
  
  -- Set diff content
  local lines = vim.split(diff, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Get UI config
  local config = require("claucode").get_config()
  local ui_config = config.ui.diff
  
  -- Calculate window size
  local width = math.floor(vim.o.columns * ui_config.width)
  local height = math.floor(vim.o.lines * ui_config.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = ui_config.border,
    title = " Claude wants to modify: " .. vim.fn.fnamemodify(filepath, ":t") .. " ",
    title_pos = "center",
  })
  
  -- Add instructions at the top
  local instruction_lines = {
    "# Press 'a' to accept changes, 'r' to reject, 'q' to close (and reject)",
    "",
  }
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, instruction_lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Set up keymaps
  local function cleanup()
    pcall(vim.api.nvim_win_close, win, true)
    pending_diffs[filepath] = nil
  end
  
  -- Accept changes
  vim.keymap.set("n", "a", function()
    local pending = pending_diffs[filepath]
    if pending and pending.on_accept then
      pending.on_accept()
    end
    cleanup()
  end, { buffer = buf })
  
  -- Reject changes
  vim.keymap.set("n", "r", function()
    local pending = pending_diffs[filepath]
    if pending and pending.on_reject then
      pending.on_reject()
    end
    cleanup()
  end, { buffer = buf })
  
  -- Close (same as reject)
  vim.keymap.set("n", "q", function()
    local pending = pending_diffs[filepath]
    if pending and pending.on_reject then
      pending.on_reject()
    end
    cleanup()
  end, { buffer = buf })
  
  -- Also handle Escape
  vim.keymap.set("n", "<Esc>", function()
    local pending = pending_diffs[filepath]
    if pending and pending.on_reject then
      pending.on_reject()
    end
    cleanup()
  end, { buffer = buf })
  
  return win, buf
end

return M