-- Session identity module for multi-session support
-- Generates unique identifiers per project directory to isolate MCP servers

local M = {}

-- Get the current project directory (normalized absolute path)
function M.get_project_dir()
  return vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")
end

-- Generate a unique session ID based on project directory
-- Uses first 8 characters of SHA256 hash for uniqueness while keeping it short
function M.get_session_id()
  local project_dir = M.get_project_dir()
  local hash = vim.fn.sha256(project_dir):sub(1, 8)
  return "claucode-" .. hash
end

-- Get the MCP server name for this session
function M.get_mcp_server_name()
  return M.get_session_id()
end

-- Get the communication directory for this session
-- Each session gets its own subdirectory to prevent cross-session interference
function M.get_communication_dir()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")
  return data_dir .. "/claucode/diffs/" .. M.get_session_id()
end

return M
