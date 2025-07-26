local M = {}
local config = require('claude-code.config')

M.memory = {}

function M.get(key)
  -- Check memory cache first
  if M.memory[key] then
    local entry = M.memory[key]
    if entry.expires > vim.loop.now() then
      return entry.value
    else
      M.memory[key] = nil
    end
  end
  
  -- Check disk cache
  local cache_dir = config.get().cache_dir
  local file_path = cache_dir .. '/' .. vim.fn.sha256(key) .. '.json'
  
  if vim.fn.filereadable(file_path) == 1 then
    local ok, data = pcall(function()
      local content = vim.fn.readfile(file_path)
      return vim.json.decode(table.concat(content, '\n'))
    end)
    
    if ok and data.expires > vim.loop.now() then
      -- Store in memory cache
      M.memory[key] = data
      return data.value
    else
      -- Remove expired file
      vim.fn.delete(file_path)
    end
  end
  
  return nil
end

function M.set(key, value, ttl)
  ttl = ttl or 900000 -- Default 15 minutes
  local expires = vim.loop.now() + ttl
  
  local entry = {
    value = value,
    expires = expires,
  }
  
  -- Store in memory
  M.memory[key] = entry
  
  -- Store on disk
  local cache_dir = config.get().cache_dir
  vim.fn.mkdir(cache_dir, 'p')
  
  local file_path = cache_dir .. '/' .. vim.fn.sha256(key) .. '.json'
  local ok = pcall(function()
    vim.fn.writefile({vim.json.encode(entry)}, file_path)
  end)
  
  if not ok then
    vim.notify("Failed to write cache file", vim.log.levels.WARN)
  end
end

function M.clear()
  M.memory = {}
  
  local cache_dir = config.get().cache_dir
  if vim.fn.isdirectory(cache_dir) == 1 then
    -- Remove all cache files
    local files = vim.fn.glob(cache_dir .. '/*.json', false, true)
    for _, file in ipairs(files) do
      vim.fn.delete(file)
    end
  end
end

function M.clean_expired()
  local now = vim.loop.now()
  
  -- Clean memory cache
  for key, entry in pairs(M.memory) do
    if entry.expires <= now then
      M.memory[key] = nil
    end
  end
  
  -- Clean disk cache
  local cache_dir = config.get().cache_dir
  if vim.fn.isdirectory(cache_dir) == 1 then
    local files = vim.fn.glob(cache_dir .. '/*.json', false, true)
    for _, file in ipairs(files) do
      local ok, data = pcall(function()
        local content = vim.fn.readfile(file)
        return vim.json.decode(table.concat(content, '\n'))
      end)
      
      if ok and data.expires <= now then
        vim.fn.delete(file)
      end
    end
  end
end

-- Set up periodic cleanup
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('ClaudeCodeCache', { clear = true }),
  callback = function()
    M.clean_expired()
  end,
})

return M