-- Session identity module for multi-session support
-- Generates unique identifiers per project directory to isolate MCP servers
-- Values are cached at initialization to prevent issues if user changes directory

local M = {}

-- Cached values (set once at init, never change)
local cached_project_dir = nil
local cached_session_id = nil
local cached_comm_dir = nil

-- Initialize session (call once at setup)
function M.init()
  if cached_project_dir then
    return -- Already initialized
  end
  -- Normalize path: get absolute path and remove trailing slash/backslash
  cached_project_dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
  -- Remove trailing path separator (works on both Windows and Unix)
  cached_project_dir = cached_project_dir:gsub("[/\\]$", "")
  local hash = vim.fn.sha256(cached_project_dir):sub(1, 8)
  cached_session_id = "claucode-" .. hash
  -- Use vim.fn.expand for cross-platform path handling
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")
  -- Use forward slashes for consistency (Lua/Neovim handles this on Windows)
  cached_comm_dir = data_dir .. "/claucode/diffs/" .. cached_session_id
end

-- Get the project directory (cached at init)
function M.get_project_dir()
  if not cached_project_dir then
    M.init()
  end
  return cached_project_dir
end

-- Get the session ID (cached at init)
function M.get_session_id()
  if not cached_session_id then
    M.init()
  end
  return cached_session_id
end

-- Get the MCP server name for this session
function M.get_mcp_server_name()
  return M.get_session_id()
end

-- Get the communication directory for this session (cached at init)
function M.get_communication_dir()
  if not cached_comm_dir then
    M.init()
  end
  return cached_comm_dir
end

return M
