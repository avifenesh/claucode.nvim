-- Health check for :checkhealth claucode
--
-- Neovim discovers this file automatically via `lua/<plugin>/health.lua`,
-- so callers don't need to load the main module first.

local M = {}

local function has_exec(bin)
	return vim.fn.executable(bin) == 1
end

local function run_version(cmd)
	local ok, result = pcall(vim.system, { cmd, "--version" }, { text = true, timeout = 2000 })
	if not ok or not result then return nil end
	local done = result:wait(2000)
	if not done or done.code ~= 0 then return nil end
	return vim.trim((done.stdout or "") .. (done.stderr or ""))
end

function M.check()
	local health = vim.health
	health.start("claucode.nvim")

	-- Neovim version
	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim " .. tostring(vim.version()))
	else
		health.error("Neovim 0.10+ required (current: " .. tostring(vim.version()) .. ")")
	end

	-- Main module loaded
	local mod_ok, main = pcall(require, "claucode")
	if not mod_ok then
		health.error("claucode module failed to load: " .. tostring(main))
		return
	end
	local cfg = main.config or {}

	-- Claude CLI
	local claude_cmd = cfg.command or "claude"
	if has_exec(claude_cmd) then
		health.ok("Claude Code CLI found: " .. claude_cmd)
		local version = run_version(claude_cmd)
		if version then
			health.ok("Claude Code CLI version: " .. version)
		else
			health.warn("Claude Code CLI reachable but --version failed")
		end
	else
		health.error(
			"Claude Code CLI not found",
			{ "Install: npm install -g @anthropic-ai/claude-code" }
		)
	end

	-- Auth: ANTHROPIC_API_KEY OR `claude` has logged-in creds
	if vim.env.ANTHROPIC_API_KEY and vim.env.ANTHROPIC_API_KEY ~= "" then
		health.ok("ANTHROPIC_API_KEY is set")
	else
		health.info("ANTHROPIC_API_KEY not set (expected if you authenticated via `claude login`)")
	end

	-- MCP server
	if (cfg.mcp or {}).enabled then
		local plugin_root = debug.getinfo(1, "S").source:sub(2):match("(.*/lua/claucode/).+") or ""
		plugin_root = plugin_root:gsub("/lua/claucode/$", "")
		local bundled = plugin_root .. "/mcp-server/build/index.js"
		local user_built = vim.fn.expand("~/.config/claucode/mcp-server/build/index.js")
		if vim.fn.filereadable(bundled) == 1 then
			health.ok("MCP server (bundled): " .. bundled)
		elseif vim.fn.filereadable(user_built) == 1 then
			health.ok("MCP server (user): " .. user_built)
		else
			health.warn("MCP server not built yet (auto-builds on first use)")
		end
	else
		health.info("MCP disabled in config; diff preview unavailable")
	end

	-- Toolchain
	for _, tool in ipairs({ "git", "node", "npm" }) do
		if has_exec(tool) then
			health.ok(tool .. ": available")
		else
			health.warn(tool .. " not found (required for MCP server build)")
		end
	end
end

return M
