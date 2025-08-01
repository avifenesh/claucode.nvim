local M = {}

-- Cache for MCP server connection
local mcp_job_id = nil

-- Start MCP server if not running
local function ensure_mcp_server()
  if mcp_job_id and vim.fn.jobwait({mcp_job_id}, 0)[1] == -1 then
    return true -- Already running
  end
  
  -- Start MCP server
  local mcp_path = vim.fn.expand("~/.config/nvim/mcp-nvim-diff/build/index.js")
  if vim.fn.filereadable(mcp_path) == 0 then
    vim.notify("MCP server not found. Please build it first.", vim.log.levels.ERROR)
    return false
  end
  
  mcp_job_id = vim.fn.jobstart({"node", mcp_path}, {
    on_exit = function(_, code)
      vim.notify("MCP server exited with code: " .. code, vim.log.levels.INFO)
      mcp_job_id = nil
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.notify("MCP: " .. line, vim.log.levels.DEBUG)
        end
      end
    end
  })
  
  return mcp_job_id ~= nil
end

-- Call MCP tool via Claude
local function call_mcp_tool(tool_name, params)
  -- This would need to integrate with Claude CLI
  -- For now, we'll use a direct approach
  local cmd = string.format(
    'echo \'{"jsonrpc":"2.0","method":"tools/call","params":{"name":"%s","arguments":%s}}\' | nc -U /tmp/mcp-nvim.sock',
    tool_name,
    vim.fn.json_encode(params)
  )
  
  vim.fn.system(cmd)
end

-- Show diff preview in floating window
function M.show_diff_preview(filepath, diff_id)
  -- Get diff content from MCP server
  local response = vim.fn.system({
    "curl", "-s", "-X", "POST",
    "-H", "Content-Type: application/json",
    "-d", vim.fn.json_encode({
      jsonrpc = "2.0",
      method = "tools/call",
      params = {
        name = "get_diff_content",
        arguments = { filepath = filepath }
      },
      id = 1
    }),
    "http://localhost:3000/rpc" -- Assuming MCP server has HTTP endpoint
  })
  
  local ok, diff_data = pcall(vim.fn.json_decode, response)
  if not ok or not diff_data then
    vim.notify("Failed to get diff content", vim.log.levels.ERROR)
    return
  end
  
  -- Generate diff
  local original_lines = vim.split(diff_data.original or "", "\n", { plain = true })
  local modified_lines = vim.split(diff_data.modified or "", "\n", { plain = true })
  
  -- Create diff buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
  
  -- Generate unified diff
  local diff_lines = {
    "# Press 'a' to accept changes, 'r' to reject",
    "",
    "--- " .. filepath,
    "+++ " .. filepath .. " (proposed)",
  }
  
  -- Simple diff algorithm (could be improved)
  local max_lines = math.max(#original_lines, #modified_lines)
  for i = 1, max_lines do
    local orig = original_lines[i] or ""
    local mod = modified_lines[i] or ""
    
    if orig ~= mod then
      if orig ~= "" then
        table.insert(diff_lines, "-" .. orig)
      end
      if mod ~= "" then
        table.insert(diff_lines, "+" .. mod)
      end
    else
      table.insert(diff_lines, " " .. orig)
    end
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Calculate window size
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
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
    border = "rounded",
    title = " MCP Diff Preview: " .. vim.fn.fnamemodify(filepath, ":t") .. " ",
    title_pos = "center",
  })
  
  -- Setup keymaps
  local function respond(approved)
    -- Send response back to MCP server
    call_mcp_tool("diff_response", {
      filepath = filepath,
      approved = approved
    })
    
    -- Close window
    vim.api.nvim_win_close(win, true)
  end
  
  -- Keymaps for the diff buffer
  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "a", function() respond(true) end, opts)
  vim.keymap.set("n", "r", function() respond(false) end, opts)
  vim.keymap.set("n", "q", function() respond(false) end, opts)
  vim.keymap.set("n", "<Esc>", function() respond(false) end, opts)
  
  -- Syntax highlighting for diff
  vim.cmd([[
    syn match diffAdded "^+.*"
    syn match diffRemoved "^-.*"
    syn match diffLine "^@.*"
    syn match diffFile "^---.*"
    syn match diffFile "^+++.*"
    hi link diffAdded DiffAdd
    hi link diffRemoved DiffDelete
    hi link diffLine DiffChange
    hi link diffFile DiffText
  ]])
end

-- Initialize MCP integration
function M.setup(config)
  -- Ensure MCP server is running
  ensure_mcp_server()
  
  -- Set NVIM socket for MCP server
  vim.env.NVIM = vim.v.servername
end

return M