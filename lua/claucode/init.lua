-- claucode.nvim - Bridge between Neovim and Claude Code CLI
-- Repository: https://github.com/avifenesh/claucode.nvim
-- License: MIT
-- Author: Avi Fenesh
-- Version: 0.3.0

local M = {
	-- Plugin version
	version = "0.3.0",
	-- Unique session identifier for this Neovim instance
	session_id = nil,
}

-- Generate a unique session identifier
local function generate_session_id()
	-- Seed random number generator
	math.randomseed(os.time() + vim.fn.getpid())
	-- Use PID and timestamp for uniqueness
	local pid = vim.fn.getpid()
	local time = os.time()
	local random = math.random(1000, 9999)
	return string.format("nvim-%d-%d-%d", pid, time, random)
end

-- Default configuration
M.config = {
	-- Claude Code CLI command
	command = "claude",
	-- Default model to use
	model = "claude-sonnet-4-20250514",
	-- Auto-start file watcher on setup
	auto_start_watcher = true,
	-- Enable default keymaps
	keymaps = {
		enable = true,
		prefix = "<leader>ai", -- AI prefix to avoid conflicts
	},
	-- File watcher settings
	watcher = {
		-- Debounce time in milliseconds
		debounce = 100,
		-- Ignore patterns
		ignore_patterns = {
			"%.git/",
			"node_modules/",
			"%.swp$",
			"%.swo$",
			-- Binary files
			"%.class$",
			"%.jar$",
			"%.war$",
			"%.ear$", -- Java
			"%.pyc$",
			"%.pyo$",
			"%.pyd$", -- Python
			"%.exe$",
			"%.dll$",
			"%.so$",
			"%.dylib$", -- Executables/Libraries
			"%.o$",
			"%.a$",
			"%.lib$", -- Object files
			"%.pdf$",
			"%.jpg$",
			"%.jpeg$",
			"%.png$", -- Media files
			"%.gif$",
			"%.bmp$",
			"%.ico$",
			"%.webp$",
			"%.mp3$",
			"%.mp4$",
			"%.avi$",
			"%.mov$",
			"%.zip$",
			"%.tar$",
			"%.gz$",
			"%.rar$", -- Archives
			"%.db$",
			"%.sqlite$",
			"%.sqlite3$", -- Databases
		},
	},
	-- Bridge settings
	bridge = {
		-- Timeout for CLI commands in milliseconds
		timeout = 30000,
		-- Max output buffer size
		max_output = 1048576, -- 1MB
		-- Show diff before applying changes (requires MCP)
		show_diff = false,
		-- Automatically add diff instructions to CLAUDE.md
		auto_claude_md = true,
	},
	-- MCP settings
	mcp = {
		-- Enable MCP server for diff preview
		enabled = true,
		-- Auto-build MCP server if not found
		auto_build = true,
		-- Server name (auto-generated with session ID if nil)
		server_name = nil,
	},
	-- UI settings
	ui = {
		-- Diff preview window settings
		diff = {
			width = 0.8,
			height = 0.8,
			border = "rounded",
		},
		-- Terminal settings
		terminal = {
			height = 0.5, -- 50% of screen height (increased from 30%)
		},
		-- Icon settings
		icons = {
			enabled = true, -- Set to false to disable icons/emojis
		},
	},
	-- Notification settings
	notifications = {
		-- Reduce noise by silencing routine operations
		silent_watcher = true, -- Don't notify on watcher start/stop
		silent_claude_md = true, -- Don't notify on CLAUDE.md updates
	},
}

local function find_claude_command()
	-- First check if 'claude' is in PATH
	if vim.fn.executable("claude") == 1 then
		return "claude"
	end

	-- Check common installation paths
	local common_paths = {
		vim.fn.expand("~/.claude/local/claude"),
		vim.fn.expand("~/node_modules/.bin/claude"),
		"/usr/local/bin/claude",
		"/opt/homebrew/bin/claude",
	}

	for _, path in ipairs(common_paths) do
		-- Check if file exists and is readable
		if vim.fn.filereadable(path) == 1 then
			-- Test if we can actually run it
			local handle = io.popen(path .. " --version 2>&1")
			if handle then
				local result = handle:read("*a")
				handle:close()
				if result:match("Claude Code") then
					return path
				end
			end
		end
	end

	return "claude" -- fallback
end

local function merge_config(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

	-- Auto-detect claude command if not specified
	if M.config.command == "claude" and vim.fn.executable("claude") == 0 then
		local detected = find_claude_command()
		if detected ~= "claude" then
			M.config.command = detected
			-- Removed startup notification to reduce noise
		end
	end
end

function M.setup(user_config)
	-- Generate session ID first
	M.session_id = generate_session_id()
	
	merge_config(user_config)

	-- Validate configuration
	if M.config.bridge.show_diff and not M.config.mcp.enabled then
		local notify = require("claucode.notify")
		notify.warn("show_diff requires MCP to be enabled. Disabling show_diff.")
		M.config.bridge.show_diff = false
	end

	-- Load modules
	require("claucode.commands").setup(M.config)

	if M.config.keymaps.enable then
		require("claucode.keymaps").setup(M.config)
	end

	if M.config.auto_start_watcher then
		require("claucode.watcher").start(M.config)
	end

	-- Setup MCP integration if enabled
	if M.config.mcp.enabled then
		-- Build MCP server if needed
		require("claucode.mcp").setup(M.config)
		-- Add MCP server to Claude configuration
		require("claucode.mcp_manager").setup(M.config)
	end

	-- Setup CLAUDE.md management for diff preview
	if M.config.mcp.enabled and M.config.bridge.show_diff then
		require("claucode.claude_md").setup()
	end

	-- Create user commands
	vim.api.nvim_create_user_command("Claude", function(opts)
		-- Check if called from visual mode
		local from_visual = opts.range > 0
		if from_visual then
			require("claucode.commands").store_visual_selection()
		end
		
		-- If no args provided, open input prompt
		if opts.args == "" and not from_visual then
			vim.ui.input({ prompt = "Claude prompt: " }, function(input)
				if input and input ~= "" then
					require("claucode.commands").claude(input, false)
				end
			end)
		else
			require("claucode.commands").claude(opts.args, from_visual)
		end
	end, {
		nargs = "*",
		range = true,
		desc = "Send a prompt to Claude Code CLI",
	})



	vim.api.nvim_create_user_command("ClaudeTerminal", function(opts)
		require("claucode.terminal").open_claude_terminal(opts.args)
	end, {
		nargs = "*",
		desc = "Open Claude in a terminal split with optional CLI parameters",
	})

	vim.api.nvim_create_user_command("ClaudeTerminalToggle", function()
		require("claucode.terminal").toggle_claude_terminal()
	end, {
		desc = "Toggle Claude terminal",
	})



	vim.api.nvim_create_user_command("ClaudeDiffToggle", function()
		-- Toggle the show_diff configuration
		M.config.bridge.show_diff = not M.config.bridge.show_diff
		
		if M.config.bridge.show_diff then
			-- Enable diff preview
			if M.config.mcp.enabled then
				-- Start diff watcher
				require("claucode.mcp").start_diff_watcher()
				-- Add diff instructions to CLAUDE.md
				require("claucode.claude_md").add_diff_instructions()
				-- Add MCP server to Claude configuration
				require("claucode.mcp_manager").add_mcp_server(function(success)
					if success then
						local notify = require("claucode.notify")
						notify.info("Diff preview enabled (MCP server added)")
						notify.warn("Note: Restart Claude terminal session for changes to take effect")
					else
						local notify = require("claucode.notify")
						notify.warn("Diff preview enabled (MCP server may not be registered)")
					end
				end)
			else
				local notify = require("claucode.notify")
				notify.warn("Cannot enable diff preview - MCP is disabled in config")
				M.config.bridge.show_diff = false
			end
		else
			-- Disable diff preview
			require("claucode.mcp").stop_diff_watcher()
			require("claucode.claude_md").remove_diff_instructions()
			-- Remove MCP server from Claude configuration
			require("claucode.mcp_manager").remove_mcp_server()
			local notify = require("claucode.notify")
			notify.info("Diff preview disabled (MCP server removed)")
			notify.warn("Note: Restart Claude terminal session for changes to take effect")
		end
	end, {
		desc = "Toggle Claucode diff preview on/off",
	})
	
	-- Setup cleanup on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("ClaucodeCleanup", { clear = true }),
		callback = function()
			-- Stop watchers and timers
			local ok_watcher, watcher = pcall(require, "claucode.watcher")
			if ok_watcher and watcher.stop then
				watcher.stop()
			end
			
			local ok_mcp, mcp = pcall(require, "claucode.mcp")
			if ok_mcp and mcp.cleanup then
				mcp.cleanup()
			end
			
			-- Remove session-specific MCP server
			if M.config.mcp.enabled and M.config.bridge.show_diff then
				local ok_mgr, mgr = pcall(require, "claucode.mcp_manager")
				if ok_mgr and mgr.remove_mcp_server then
					mgr.remove_mcp_server()
				end
			end
		end,
	})
end

function M.get_config()
	return M.config
end

-- Get the session ID for this Neovim instance
function M.get_session_id()
	-- Lazy initialization if setup() wasn't called
	if not M.session_id then
		M.session_id = generate_session_id()
	end
	return M.session_id
end

-- Get the MCP server name (with session ID if needed)
function M.get_mcp_server_name()
	if M.config.mcp.server_name then
		return M.config.mcp.server_name
	end
	-- Default: use session-specific name for multi-instance support
	return "claucode-nvim-" .. M.session_id
end

-- Health check function for :checkhealth
function M.health()
	local health = vim.health or require("health")
	local start = health.start or health.report_start
	local ok = health.ok or health.report_ok
	local warn = health.warn or health.report_warn
	local error = health.error or health.report_error
	
	start("claucode.nvim")
	
	-- Check Neovim version
	if vim.fn.has("nvim-0.5.0") == 1 then
		ok("Neovim version >= 0.5.0")
	else
		error("Neovim version < 0.5.0. Please upgrade Neovim.")
	end
	
	-- Check Claude CLI
	local claude_cmd = M.config.command or "claude"
	if vim.fn.executable(claude_cmd) == 1 then
		ok("Claude Code CLI found: " .. claude_cmd)
		
		-- Check version
		local handle = io.popen(claude_cmd .. " --version 2>&1")
		if handle then
			local version = handle:read("*a")
			handle:close()
			if version and version:match("Claude Code") then
				ok("Claude Code CLI version: " .. version:gsub("\n", ""))
			end
		end
	else
		error("Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code")
	end
	
	-- Check API key
	if vim.fn.getenv("ANTHROPIC_API_KEY") ~= vim.NIL then
		ok("ANTHROPIC_API_KEY is set")
	else
		warn("ANTHROPIC_API_KEY not set. You may need to authenticate via other methods.")
	end
	
	-- Check MCP server if enabled
	if M.config.mcp.enabled then
		local mcp_server_path = vim.fn.expand("~/.config/claucode/mcp-server/build/index.js")
		if vim.fn.filereadable(mcp_server_path) == 1 then
			ok("MCP server built and ready")
		else
			warn("MCP server not built. Will be built on first use.")
		end
	end
	
	-- Check Git (for diff functionality)
	if vim.fn.executable("git") == 1 then
		ok("Git is installed")
	else
		warn("Git not found. Diff functionality may be limited.")
	end
	
	-- Check Node.js and npm (for MCP)
	if vim.fn.executable("node") == 1 then
		ok("Node.js is installed")
	else
		warn("Node.js not found. Required for MCP server.")
	end
	
	if vim.fn.executable("npm") == 1 then
		ok("npm is installed")
	else
		warn("npm not found. Required for installing Claude CLI and building MCP server.")
	end
end

-- Utility function to get plugin status
function M.status()
	local status = {
		version = M.version,
		claude_command = M.config.command,
		mcp_enabled = M.config.mcp.enabled,
		diff_preview = M.config.bridge.show_diff,
		watcher_active = false,
		terminal_open = false,
	}
	
	-- Check if watcher is running
	local ok, watcher = pcall(require, "claucode.watcher")
	if ok and watcher.is_running then
		status.watcher_active = watcher.is_running()
	end
	
	-- Check if terminal is open
	local ok_term, terminal = pcall(require, "claucode.terminal")
	if ok_term and terminal.is_open then
		status.terminal_open = terminal.is_open()
	end
	
	return status
end

-- Debug function to help troubleshoot issues
function M.debug_info()
	local info = {
		config = M.config,
		status = M.status(),
		nvim_version = vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
		os = vim.loop.os_uname().sysname,
		cwd = vim.fn.getcwd(),
	}
	
	-- Pretty print the debug info
	vim.notify(vim.inspect(info), vim.log.levels.INFO, { title = "Claucode Debug Info" })
	return info
end

return M
