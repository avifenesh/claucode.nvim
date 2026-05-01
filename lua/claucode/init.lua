-- claucode.nvim - Bridge between Neovim and Claude Code CLI
-- Repository: https://github.com/avifenesh/claucode.nvim
-- License: MIT
-- Author: Avi Fenesh

local M = {
	version = "0.3.1",
}

-- Default configuration
M.config = {
	-- Claude Code CLI command (looked up on PATH by default)
	command = "claude",
	-- Model override: nil = let the Claude Code CLI pick its default
	model = nil,
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
		-- Show diff before applying changes (requires MCP). Flagship feature — on by default.
		show_diff = true,
		-- Automatically add diff instructions to CLAUDE.md
		auto_claude_md = true,
		-- Auto-accept (passthrough): if true, the MCP server writes files
		-- immediately without prompting in Neovim. Toggle at runtime with
		-- :ClaudeAutoAccept — takes effect on the very next tool call, no
		-- Claude session restart required.
		auto_accept = false,
	},
	-- MCP settings
	mcp = {
		-- Enable MCP server for diff preview
		enabled = true,
		-- Auto-build MCP server if not found
		auto_build = true,
		-- Remove MCP server when Neovim exits (for multi-session support)
		cleanup_on_exit = true,
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
			enabled = true, -- Set to false to disable icons/emojis in notifications
		},
	},
	-- Notification settings
	notifications = {
		-- Reduce noise by silencing routine operations
		silent_watcher = true, -- Don't notify on watcher start/stop and buffer reloads
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
		if vim.fn.filereadable(path) == 1 and vim.fn.executable(path) == 1 then
			-- Non-blocking spawn; 2s timeout is plenty for --version
			local ok, proc = pcall(vim.system, { path, "--version" }, { text = true, timeout = 2000 })
			if ok and proc then
				local result = proc:wait(2000)
				if result.code == 0 and (result.stdout or ""):match("Claude Code") then
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
	-- Neovim version guard: we rely on vim.system (0.10+) and vim.health (0.10+)
	if vim.fn.has("nvim-0.10") ~= 1 then
		vim.notify(
			"claucode.nvim requires Neovim 0.10+ (current: " .. tostring(vim.version()) .. ")",
			vim.log.levels.ERROR
		)
		return
	end

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
		-- Initialize session identity (cache project dir before any :cd)
		require("claucode.session").init()
		-- Build MCP server if needed
		require("claucode.mcp").setup(M.config)
		-- Add MCP server to Claude configuration
		require("claucode.mcp_manager").setup(M.config)

		-- Register cleanup on Neovim exit (for multi-session support)
		-- Use autogroup to prevent duplicate autocmds if setup() is called multiple times
		local augroup = vim.api.nvim_create_augroup("ClaucodeCleanup", { clear = true })
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = augroup,
			callback = function()
				-- Stop diff watcher if it was running
				if M.config.bridge.show_diff then
					require("claucode.mcp").cleanup()
				end
				-- Always clear the passthrough flag on exit
				pcall(set_passthrough, false)
				-- Remove MCP server if cleanup_on_exit is enabled
				if M.config.mcp.cleanup_on_exit ~= false then
					require("claucode.mcp_manager").remove_mcp_server()
				end
			end,
			desc = "Claucode cleanup on exit"
		})

		-- Honor initial config.bridge.auto_accept
		if M.config.bridge.auto_accept then
			set_passthrough(true)
		else
			-- Clear any stale flag from a previous crashed session
			set_passthrough(false)
		end
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

		-- If no args provided, open input prompt (works for both normal and visual mode)
		local args = vim.trim(opts.args)
		if args == "" then
			local prompt_text = from_visual and "Claude prompt (with selection): " or "Claude prompt: "
			vim.ui.input({ prompt = prompt_text }, function(input)
				if input and vim.trim(input) ~= "" then
					require("claucode.commands").claude(vim.trim(input), from_visual)
				end
			end)
		else
			require("claucode.commands").claude(args, from_visual)
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



	vim.api.nvim_create_user_command("ClaudeAutoAccept", function(opts)
		local notify = require("claucode.notify")
		local arg = vim.trim(opts.args or ""):lower()
		local target
		if arg == "on" or arg == "true" or arg == "1" then
			target = true
		elseif arg == "off" or arg == "false" or arg == "0" then
			target = false
		else
			target = not M.config.bridge.auto_accept
		end
		set_passthrough(target)
		if target then
			notify.info("Claucode auto-accept ON — MCP writes bypass the diff UI")
		else
			notify.info("Claucode auto-accept OFF — diff UI will prompt again")
		end
	end, {
		nargs = "?",
		complete = function() return { "on", "off" } end,
		desc = "Toggle MCP auto-accept (passthrough). Runtime switch; no session restart.",
	})

	vim.api.nvim_create_user_command("ClaudeDiffToggle", function()
		local notify = require("claucode.notify")
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
						notify.info("Diff preview enabled (MCP server added)")
						notify.warn("Note: Restart Claude terminal session for changes to take effect")
					else
						notify.warn("Diff preview enabled (MCP server may not be registered)")
					end
				end)
			else
				notify.warn("Cannot enable diff preview - MCP is disabled in config")
				M.config.bridge.show_diff = false
			end
		else
			-- Disable diff preview
			require("claucode.mcp").stop_diff_watcher()
			require("claucode.claude_md").remove_diff_instructions()
			-- Remove MCP server from Claude configuration
			require("claucode.mcp_manager").remove_mcp_server()
			notify.info("Diff preview disabled (MCP server removed)")
			notify.warn("Note: Restart Claude terminal session for changes to take effect")
		end
	end, {
		desc = "Toggle Claucode diff preview on/off",
	})
end

function M.get_config()
	return M.config
end

-- Set the MCP passthrough flag. When on, the MCP server writes files
-- immediately without asking Neovim — effect is picked up by the very next
-- tool call. No Claude session restart, no CLAUDE.md changes.
local function set_passthrough(enabled)
	local comm_dir = require("claucode.session").get_communication_dir()
	vim.fn.mkdir(comm_dir, "p")
	local flag = comm_dir .. "/passthrough.flag"
	if enabled then
		vim.fn.writefile({ tostring(os.time()) }, flag)
	else
		if vim.fn.filereadable(flag) == 1 then
			os.remove(flag)
		end
	end
	M.config.bridge.auto_accept = enabled
end

function M.set_auto_accept(enabled)
	set_passthrough(enabled and true or false)
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
		os = (vim.uv or vim.loop).os_uname().sysname,
		cwd = vim.fn.getcwd(),
	}
	
	-- Pretty print the debug info
	vim.notify(vim.inspect(info), vim.log.levels.INFO, { title = "Claucode Debug Info" })
	return info
end

return M
