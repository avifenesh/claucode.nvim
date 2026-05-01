# Changelog

## v0.3.1 — 2026-05-01

### Added
- **`:ClaudeAutoAccept [on|off]`** — runtime passthrough flag. When enabled, the MCP server writes files immediately without showing the diff UI. Takes effect on the very next tool call; no Claude session restart, no `CLAUDE.md` changes. Useful for autonomous runs. Cleared on Neovim exit.
- `bridge.auto_accept = false` config option to start a session with passthrough already on.
- `lua/claucode/health.lua` — proper `:checkhealth claucode` support (module is loaded lazily by Neovim's health framework, so it now reports even before `setup()` has run).

### Changed
- **Flagship feature is on by default:** `bridge.show_diff` now defaults to `true`. If you relied on the old default, set it to `false` in your config.
- Minimum Neovim bumped to **0.10** (`vim.system`, `vim.uv`, modern `vim.health`). A friendly error replaces the silent failure on older versions.
- Replaced blocking `io.popen` CLI detection with non-blocking `vim.system` — faster startup on slow filesystems.
- Normalized `vim.loop` to `vim.uv` throughout (`vim.loop` is deprecated since 0.10).
- Dropped the hardcoded `claude-sonnet-4-20250514` model SKU in defaults. The Claude CLI chooses its own default now; override via your config if you need a specific model.

### Removed
- Old `M.health()` function on the main module — replaced by `lua/claucode/health.lua`.

## v0.3.0

Initial MCP diff preview, multi-session support, interactive `:Claude` prompt, notification controls. See git history.
