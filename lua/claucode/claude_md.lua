local M = {}

-- Template for diff preview instructions
local DIFF_PREVIEW_INSTRUCTIONS = [[

## Neovim Diff Preview Tools

IMPORTANT: This project has Neovim diff preview tools available. You MUST use these tools for ALL file operations:

- **ALWAYS use `nvim_edit_with_diff`** instead of `Edit` for editing files
- **ALWAYS use `nvim_write_with_diff`** instead of `Write` for writing/creating files

These tools will show changes in Neovim before applying them, allowing the user to review and approve/reject changes interactively.

### Why use these tools?
1. Users can see exactly what changes will be made before they're applied
2. Changes can be reviewed in Neovim's familiar diff interface
3. Users maintain full control over what modifications are accepted

### Usage:
When you need to edit or write files, use:
- `nvim_edit_with_diff` with parameters: file_path, old_string, new_string
- `nvim_write_with_diff` with parameters: file_path, content

DO NOT use the standard Edit/Write tools when these Neovim-specific tools are available.
]]

-- Check if CLAUDE.md exists in project root
function M.claude_md_exists()
  local cwd = vim.fn.getcwd()
  local claude_md = cwd .. "/CLAUDE.md"
  return vim.fn.filereadable(claude_md) == 1
end

-- Read CLAUDE.md content
function M.read_claude_md()
  local cwd = vim.fn.getcwd()
  local claude_md = cwd .. "/CLAUDE.md"
  
  if not M.claude_md_exists() then
    return nil
  end
  
  local file = io.open(claude_md, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  return content
end

-- Check if diff preview instructions are already in CLAUDE.md
function M.has_diff_instructions()
  local content = M.read_claude_md()
  if not content then
    return false
  end
  
  -- Check for our specific markers
  return content:find("## Neovim Diff Preview Tools") ~= nil
end

-- Add diff preview instructions to CLAUDE.md
function M.add_diff_instructions()
  local cwd = vim.fn.getcwd()
  local claude_md = cwd .. "/CLAUDE.md"
  
  -- Read existing content or start fresh
  local existing_content = M.read_claude_md() or ""
  
  -- Check if instructions already exist
  if M.has_diff_instructions() then
    return true
  end
  
  -- Append our instructions
  local new_content = existing_content
  if existing_content ~= "" and not existing_content:match("\n$") then
    new_content = new_content .. "\n"
  end
  new_content = new_content .. DIFF_PREVIEW_INSTRUCTIONS
  
  -- Write back
  local file = io.open(claude_md, "w")
  if not file then
    vim.notify("Failed to write to CLAUDE.md", vim.log.levels.ERROR)
    return false
  end
  
  file:write(new_content)
  file:close()
  
  vim.notify("Added Neovim diff preview instructions to CLAUDE.md", vim.log.levels.INFO)
  return true
end

-- Remove diff preview instructions from CLAUDE.md
function M.remove_diff_instructions()
  local content = M.read_claude_md()
  if not content or not M.has_diff_instructions() then
    return true
  end
  
  -- Remove our section (non-greedy match to avoid removing multiple sections)
  local pattern = "\n## Neovim Diff Preview Tools.-DO NOT use the standard Edit/Write tools when these Neovim%-specific tools are available%.\n"
  local new_content = content:gsub(pattern, "\n")
  
  -- Also try without leading newline in case it's at the start
  if new_content == content then
    pattern = "## Neovim Diff Preview Tools.-DO NOT use the standard Edit/Write tools when these Neovim%-specific tools are available%.\n"
    new_content = content:gsub(pattern, "")
  end
  
  -- Clean up any duplicate newlines
  new_content = new_content:gsub("\n\n+", "\n\n")
  new_content = new_content:gsub("^\n+", "")
  new_content = new_content:gsub("\n+$", "\n")
  
  local cwd = vim.fn.getcwd()
  local claude_md = cwd .. "/CLAUDE.md"
  
  local file = io.open(claude_md, "w")
  if not file then
    vim.notify("Failed to update CLAUDE.md", vim.log.levels.ERROR)
    return false
  end
  
  file:write(new_content)
  file:close()
  
  vim.notify("Removed Neovim diff preview instructions from CLAUDE.md", vim.log.levels.INFO)
  return true
end

-- Setup function to manage CLAUDE.md based on config
function M.setup()
  local config = require("claucode").get_config()
  
  -- Only manage CLAUDE.md if MCP is enabled and show_diff is true and auto_claude_md is enabled
  if config.mcp and config.mcp.enabled and 
     config.bridge and config.bridge.show_diff and 
     config.bridge.auto_claude_md ~= false then  -- Default to true if not specified
    -- Automatically add instructions if they don't exist
    if not M.has_diff_instructions() then
      -- Delay execution to ensure Neovim is fully loaded
      vim.defer_fn(function()
        M.add_diff_instructions()
      end, 100)
    end
  end
end

-- Command to manually add/remove instructions
function M.toggle_diff_instructions()
  if M.has_diff_instructions() then
    M.remove_diff_instructions()
  else
    M.add_diff_instructions()
  end
end

return M