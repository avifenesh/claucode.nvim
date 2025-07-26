local M = {}
M.__index = M

function M:new()
  return setmetatable({
    buffer = "",
    decoder = vim.json.decode
  }, self)
end

function M:feed(chunk)
  self.buffer = self.buffer .. chunk
  local messages = {}
  
  while true do
    local newline_pos = self.buffer:find("\n")
    if not newline_pos then break end
    
    local line = self.buffer:sub(1, newline_pos - 1)
    self.buffer = self.buffer:sub(newline_pos + 1)
    
    if line ~= "" then
      local ok, msg = pcall(self.decoder, line)
      if ok then
        table.insert(messages, msg)
      else
        vim.schedule(function()
          vim.notify("Failed to parse JSON: " .. line, vim.log.levels.WARN)
        end)
      end
    end
  end
  
  return messages
end

function M:clear()
  self.buffer = ""
end

return M