local M = {}

local config = nil

function M.setup(cfg)
  config = cfg
end

-- Store visual selection globally to preserve it
local visual_selection = nil

function M.store_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(
    0,
    start_pos[2] - 1,
    end_pos[2],
    false
  )
  
  if #lines > 0 then
    local mode = vim.fn.visualmode()
    -- Adjust first and last line based on column positions for character-wise selection
    if mode == "v" then
      lines[1] = lines[1]:sub(start_pos[3])
      if #lines > 1 then
        lines[#lines] = lines[#lines]:sub(1, end_pos[3])
      else
        lines[1] = lines[1]:sub(1, end_pos[3] - start_pos[3] + 1)
      end
    end
    
    visual_selection = table.concat(lines, "\n")
  end
end

function M.claude(args, from_visual)
  local bridge = require("claucode.bridge")
  
  if args == "" then
    vim.notify("Usage: :Claude <prompt>", vim.log.levels.WARN)
    return
  end
  
  -- Check if we should include current file context
  local include_file = false
  local prompt = args
  
  -- Parse --file flag
  if args:match("^%-%-file%s+") then
    include_file = true
    prompt = args:gsub("^%-%-file%s+", "")
  elseif args:match("^%-f%s+") then
    include_file = true
    prompt = args:gsub("^%-f%s+", "")
  end
  
  -- If called from visual mode or we have a stored selection, include it
  if from_visual and visual_selection then
    prompt = prompt .. "\n\nSelected code:\n```\n" .. visual_selection .. "\n```"
    -- Clear the selection after use
    visual_selection = nil
  end
  
  -- Add file context if requested or if we have a current file
  local current_file = vim.api.nvim_buf_get_name(0)
  if include_file and current_file ~= "" then
    local file_content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    local file_type = vim.bo.filetype
    prompt = prompt .. "\n\nCurrent file (" .. current_file .. "):\n```" .. file_type .. "\n" .. file_content .. "\n```"
  end
  
  -- Prompt validation complete
  
  -- Register streaming callbacks for real-time feedback
  local ui = require("claucode.ui")
  
  bridge.register_callback("on_start", function()
    vim.schedule(function()
      ui.start_streaming()
    end)
  end)
  
  bridge.register_callback("on_stream", function(text)
    vim.schedule(function()
      ui.stream_content(text)
    end)
  end)
  
  bridge.register_callback("on_tool_use", function(tool_data)
    vim.schedule(function()
      ui.on_tool_use(tool_data)
    end)
  end)
  
  bridge.register_callback("on_result", function(result)
    vim.schedule(function()
      ui.finish_streaming()
      if result.is_error then
        vim.notify("Claude error: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  end)
  
  -- Send to Claude
  local success = bridge.send_to_claude(prompt, {
    include_current_file = include_file,
  })
  
  if not success then
    vim.notify("Failed to send prompt to Claude Code", vim.log.levels.ERROR)
  end
end

function M.claude_file()
  -- Convenience command to send current file to Claude
  M.claude("--file Please review this file and suggest improvements")
end

function M.claude_explain()
  -- Explain the current code
  if visual_selection then
    M.claude("Explain this code", true)
  else
    M.claude("--file Explain this file")
  end
end

function M.claude_fix()
  -- Fix issues in current file or selection
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    M.claude("Fix any issues in this code")
  else
    M.claude("--file Fix any issues in this file")
  end
end

function M.claude_test()
  -- Generate tests
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    M.claude("Write tests for this code")
  else
    M.claude("--file Write tests for this file")
  end
end


function M.claude_complete()
  -- Complete code at cursor
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)
  local current_line = lines[row]
  
  -- Get context before cursor
  local before_cursor = current_line:sub(1, col)
  local context = table.concat(lines, "\n")
  
  local prompt = "Complete the code at this position:\n\n```\n" .. 
                 context .. "\n" .. 
                 before_cursor .. "█" .. -- Cursor position
                 "\n```\n\nProvide only the completion, no explanation."
  
  M.claude(prompt)
end

return M