local M = {}
M.__index = M

function M:new(threshold, timeout)
  return setmetatable({
    failures = 0,
    threshold = threshold or 5,
    timeout = timeout or 60000, -- 1 minute
    state = "closed", -- closed, open, half-open
    last_failure = 0,
  }, M)
end

function M:call(fn, ...)
  if self.state == "open" then
    local now = vim.loop.now()
    if now - self.last_failure > self.timeout then
      self.state = "half-open"
    else
      return nil, "Circuit breaker is open"
    end
  end
  
  local ok, result = pcall(fn, ...)
  
  if ok then
    if self.state == "half-open" then
      self.state = "closed"
    end
    self.failures = 0
    return result
  else
    self.failures = self.failures + 1
    self.last_failure = vim.loop.now()
    
    if self.failures >= self.threshold then
      self.state = "open"
      vim.schedule(function()
        vim.notify("Claude Code circuit breaker opened due to repeated failures", vim.log.levels.WARN)
      end)
    end
    
    return nil, result
  end
end

function M:reset()
  self.failures = 0
  self.state = "closed"
  self.last_failure = 0
end

function M:get_state()
  return {
    state = self.state,
    failures = self.failures,
    threshold = self.threshold,
  }
end

return M