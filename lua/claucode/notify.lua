-- Notification helper module
-- Provides centralized notification management with icon support and noise reduction

local M = {}

-- Cache for config to avoid repeated module loading
local config_cache = nil

-- Get cached config (refreshes on each call to handle runtime changes)
local function get_config()
  local ok, claucode = pcall(require, "claucode")
  if ok then
    config_cache = claucode.get_config()
  end
  return config_cache or {}
end

-- Get icon based on level and config
local function get_icon(level)
  local config = get_config()
  if not config.ui or not config.ui.icons or config.ui.icons.enabled == false then
    return ""
  end

  local icons = {
    [vim.log.levels.ERROR] = "❌ ",
    [vim.log.levels.WARN] = "⚠️  ",
    [vim.log.levels.INFO] = "ℹ️  ",
    [vim.log.levels.DEBUG] = "🔍 ",
  }

  return icons[level] or ""
end

-- Core notification function
local function notify(message, level, opts)
  opts = opts or {}

  -- Add icon prefix
  local icon = get_icon(level)
  local full_message = icon .. message

  vim.notify(full_message, level, { title = "Claucode" })
end

-- Public API

-- Error notifications (always shown)
function M.error(message, opts)
  notify(message, vim.log.levels.ERROR, opts)
end

-- Warning notifications (always shown)
function M.warn(message, opts)
  notify(message, vim.log.levels.WARN, opts)
end

-- Info notifications (always shown for important messages)
function M.info(message, opts)
  notify(message, vim.log.levels.INFO, opts)
end

-- Watcher notifications (respects silent_watcher config)
function M.watcher(message, opts)
  local config = get_config()
  if config.notifications and config.notifications.silent_watcher then
    return -- Silent mode enabled
  end
  notify(message, vim.log.levels.INFO, opts)
end

-- CLAUDE.md notifications (respects silent_claude_md config)
function M.claude_md(message, opts)
  local config = get_config()
  if config.notifications and config.notifications.silent_claude_md then
    return -- Silent mode enabled
  end
  notify(message, vim.log.levels.INFO, opts)
end

-- MCP setup notifications (silent by default, only show on force)
function M.mcp_setup(message, opts)
  opts = opts or {}
  if opts.force then
    notify(message, vim.log.levels.INFO, opts)
  end
end

-- Buffer reload notifications (respects silent_watcher config)
function M.buffer_reload(message, opts)
  local config = get_config()
  if config.notifications and config.notifications.silent_watcher then
    return -- Silent mode enabled
  end
  notify(message, vim.log.levels.INFO, opts)
end

return M
