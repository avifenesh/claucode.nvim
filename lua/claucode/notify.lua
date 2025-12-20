-- Notification helper module
-- Provides centralized notification management with icon support and noise reduction

local M = {}

-- Cache for config to avoid repeated module loading
local config_cache = nil

-- Get cached config
local function get_cached_config()
	if not config_cache then
		config_cache = require("claucode").get_config()
	end
	return config_cache
end

-- Get icon based on level and config
local function get_icon(level)
	local config = get_cached_config()
	if not config.ui.icons.enabled then
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
	
	-- Apply notification options
	local notify_opts = vim.tbl_extend("force", {
		title = opts.title or "Claucode",
	}, opts)
	
	vim.notify(full_message, level, notify_opts)
end

-- Public API with noise reduction

-- Error notifications (always shown)
function M.error(message, opts)
	notify(message, vim.log.levels.ERROR, opts)
end

-- Warning notifications (always shown)
function M.warn(message, opts)
	notify(message, vim.log.levels.WARN, opts)
end

-- Info notifications (respects silence settings)
function M.info(message, opts)
	notify(message, vim.log.levels.INFO, opts)
end

-- Silent notifications for routine operations (only shown if verbose mode enabled)
function M.debug(message, opts)
	-- Only show in debug mode or if explicitly requested
	if opts and opts.force then
		notify(message, vim.log.levels.DEBUG, opts)
	end
	-- Otherwise, silently ignore for noise reduction
end

-- Watcher notifications (respects silent_watcher config)
function M.watcher(message, opts)
	local config = get_cached_config()
	if not config.notifications.silent_watcher then
		notify(message, vim.log.levels.INFO, opts)
	end
end

-- CLAUDE.md notifications (respects silent_claude_md config)
function M.claude_md(message, opts)
	local config = get_cached_config()
	if not config.notifications.silent_claude_md then
		notify(message, vim.log.levels.INFO, opts)
	end
end

-- MCP setup notifications (silent by default)
function M.mcp_setup(message, opts)
	-- Only show if explicitly not silenced
	if opts and opts.force then
		notify(message, vim.log.levels.INFO, opts)
	end
end

return M
