-- AI Agents management for claude-code.nvim
local M = {}

-- Available agents
M.agents = {
  {
    name = "refactor",
    description = "Specialized in code refactoring and optimization",
    capabilities = {
      "Extract functions and methods",
      "Rename variables and functions",
      "Optimize performance",
      "Remove code duplication",
    },
  },
  {
    name = "test-writer",
    description = "Generates comprehensive test suites",
    capabilities = {
      "Unit test generation",
      "Integration test creation",
      "Test coverage analysis",
      "Mock and stub generation",
    },
  },
  {
    name = "documenter",
    description = "Creates and maintains documentation",
    capabilities = {
      "API documentation",
      "Code comments",
      "README files",
      "Architecture documentation",
    },
  },
  {
    name = "security",
    description = "Security analysis and fixes",
    capabilities = {
      "Vulnerability scanning",
      "Security best practices",
      "Dependency auditing",
      "Code hardening",
    },
  },
  {
    name = "performance",
    description = "Performance optimization specialist",
    capabilities = {
      "Bottleneck identification",
      "Algorithm optimization",
      "Memory usage reduction",
      "Caching strategies",
    },
  },
}

-- Get available agents
function M.get_available()
  -- TODO: Load custom agents from configuration
  return M.agents
end

-- Activate an agent
function M.activate(name)
  local agent = nil
  for _, a in ipairs(M.agents) do
    if a.name == name then
      agent = a
      break
    end
  end
  
  if not agent then
    vim.notify("Unknown agent: " .. name, vim.log.levels.ERROR)
    return
  end
  
  -- Send activation request to Claude Code
  require('claude-code.actions').send_request({
    type = 'activate_agent',
    agent = name,
  }, function(response)
    if response.success then
      vim.notify("Agent activated: " .. agent.description, vim.log.levels.INFO)
    else
      vim.notify("Failed to activate agent: " .. (response.error or "Unknown error"), vim.log.levels.ERROR)
    end
  end)
end

-- Get current active agent
function M.get_active()
  -- TODO: Track active agent state
  return nil
end

return M