local M = {}

local popup_buf = nil
local popup_win = nil
local stream_win = nil
local stream_buf = nil
local tool_win = nil -- Top-right window for tool usage
local tool_buf = nil
local content_accumulator = ""
local stream_timer = nil -- Debounce timer for streaming messages
local current_stream_message = ""

-- Helper to get icon if enabled in config
local function get_icon(icon)
	local ok, claucode = pcall(require, "claucode")
	if ok then
		local config = claucode.get_config()
		if config.ui and config.ui.icons and config.ui.icons.enabled then
			return icon
		end
	end
	return ""
end

-- Create streaming message window in bottom-right
function M._create_stream_window()
	-- Create stream buffer if it doesn't exist
	if not stream_buf or not vim.api.nvim_buf_is_valid(stream_buf) then
		stream_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[stream_buf].buftype = "nofile"
		vim.bo[stream_buf].swapfile = false
		vim.bo[stream_buf].filetype = "markdown"
	end

	-- Calculate window dimensions - bottom right corner
	local width = math.min(60, math.floor(vim.o.columns * 0.4))
	local height = math.min(10, math.floor(vim.o.lines * 0.2))

	-- Position in bottom right
	local row = vim.o.lines - height - 3
	local col = vim.o.columns - width - 2

	-- Create stream window if it doesn't exist
	if not stream_win or not vim.api.nvim_win_is_valid(stream_win) then
		stream_win = vim.api.nvim_open_win(stream_buf, false, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " Claude ",
			title_pos = "center",
			focusable = false,
		})

		-- Set window options
		vim.wo[stream_win].wrap = true
		vim.wo[stream_win].linebreak = true
	end
end

-- Show streaming message with debounce
function M._show_stream_message(content)
	-- Cancel previous timer
	if stream_timer then
		vim.fn.timer_stop(stream_timer)
	end

	-- Update current message
	current_stream_message = content

	-- Create or update stream window
	M._create_stream_window()

	-- Update buffer content
	local lines = vim.split(content, "\n")
	vim.api.nvim_buf_set_lines(stream_buf, 0, -1, false, lines)

	-- Auto-hide after 2 seconds of no updates
	stream_timer = vim.fn.timer_start(2000, function()
		M.close_stream_window()
		stream_timer = nil
	end)
end

-- Create tool usage window in top-right
function M._create_tool_window()
	-- Create tool buffer if it doesn't exist
	if not tool_buf or not vim.api.nvim_buf_is_valid(tool_buf) then
		tool_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[tool_buf].buftype = "nofile"
		vim.bo[tool_buf].swapfile = false
		vim.bo[tool_buf].filetype = "markdown"
	end

	-- Calculate window dimensions - top right corner
	local width = math.min(50, math.floor(vim.o.columns * 0.3))
	local height = math.min(8, math.floor(vim.o.lines * 0.15))

	-- Position in top right
	local row = 2
	local col = vim.o.columns - width - 2

	-- Create tool window if it doesn't exist
	if not tool_win or not vim.api.nvim_win_is_valid(tool_win) then
		tool_win = vim.api.nvim_open_win(tool_buf, false, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " Tools ",
			title_pos = "center",
			focusable = false,
		})

		-- Set window options
		vim.wo[tool_win].wrap = true
		vim.wo[tool_win].linebreak = true
	end
end

-- Show tool usage message in top-right
function M._show_tool_message(content)
	-- Create or update tool window
	M._create_tool_window()

	-- Update buffer content
	local lines = vim.split(content, "\n")
	vim.api.nvim_buf_set_lines(tool_buf, 0, -1, false, lines)

	-- Auto-hide after 3 seconds
	vim.defer_fn(function()
		M.close_tool_window()
	end, 3000)
end

function M.show_response(content)
	-- Create buffer if it doesn't exist
	if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
		popup_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[popup_buf].buftype = "nofile"
		vim.bo[popup_buf].swapfile = false
		vim.bo[popup_buf].filetype = "markdown"
	end

	-- Split content into lines
	local lines = vim.split(content, "\n")
	vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)

	-- Get editor dimensions
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")

	-- Calculate popup size (80% of screen)
	local win_width = math.floor(width * 0.8)
	local win_height = math.floor(height * 0.8)

	-- Calculate position (centered)
	local row = math.floor((height - win_height) / 2)
	local col = math.floor((width - win_width) / 2)

	-- Create popup window
	popup_win = vim.api.nvim_open_win(popup_buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Claude Response ",
		title_pos = "center",
	})

	-- Set window options
	vim.wo[popup_win].wrap = true
	vim.wo[popup_win].linebreak = true

	-- Add keymaps for the popup
	local opts = { noremap = true, silent = true, buffer = popup_buf }
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", opts)

	-- Scroll to top
	vim.api.nvim_win_set_cursor(popup_win, { 1, 0 })
end

function M.close_popup()
	if popup_win and vim.api.nvim_win_is_valid(popup_win) then
		vim.api.nvim_win_close(popup_win, true)
	end
	popup_win = nil
end

function M.close_stream_window()
	if stream_win and vim.api.nvim_win_is_valid(stream_win) then
		vim.api.nvim_win_close(stream_win, true)
	end
	stream_win = nil
	
	-- Cancel timer if active
	if stream_timer then
		vim.fn.timer_stop(stream_timer)
		stream_timer = nil
	end
end

function M.close_tool_window()
	if tool_win and vim.api.nvim_win_is_valid(tool_win) then
		vim.api.nvim_win_close(tool_win, true)
	end
	tool_win = nil
end

function M.start_streaming()
	content_accumulator = ""
	current_stream_message = ""

	-- Close any existing windows
	M.close_stream_window()
	M.close_tool_window()

	-- Show initial thinking message
	M._show_stream_message(get_icon("🤔 ") .. "Claude is thinking...")
end

function M.stream_content(text)
	content_accumulator = content_accumulator .. text

	-- Show streaming content in bottom-right with debounce
	local char_count = #content_accumulator
	local preview = text:sub(1, 100) -- Show first 100 chars of current chunk
	if #text > 100 then
		preview = preview .. "..."
	end

	local message = string.format("%sStreaming... (%d chars)\n%s", get_icon("💭 "), char_count, preview)
	M._show_stream_message(message)
end

function M.on_tool_use(tool_data)
	local tool_name = tool_data.name or "unknown"
	local message = string.format("%sUsing %s...", get_icon("🔧 "), tool_name)

	-- Add specific messages for common tools
	if tool_name == "Edit" then
		local file = tool_data.input and tool_data.input.file_path or "file"
		message = string.format("%sEditing %s...", get_icon("✏️  "), vim.fn.fnamemodify(file, ":t"))
	elseif tool_name == "Write" then
		local file = tool_data.input and tool_data.input.file_path or "file"
		message = string.format("%sWriting %s...", get_icon("📝 "), vim.fn.fnamemodify(file, ":t"))
	elseif tool_name == "Read" then
		local file = tool_data.input and tool_data.input.file_path or "file"
		message = string.format("%sReading %s...", get_icon("📖 "), vim.fn.fnamemodify(file, ":t"))
	elseif tool_name == "Bash" then
		local cmd = tool_data.input and tool_data.input.command or "command"
		-- Truncate long commands
		if #cmd > 30 then
			cmd = cmd:sub(1, 27) .. "..."
		end
		message = string.format("%sRunning: %s", get_icon("🖥️  "), cmd)
	end

	-- Show tool usage in top-right
	M._show_tool_message(message)
end

function M.finish_streaming()
	-- Close stream window
	M.close_stream_window()
	M.close_tool_window()
	
	-- Show final response in persistent popup
	if content_accumulator and vim.trim(content_accumulator) ~= "" then
		M.show_response(content_accumulator)
	end
	
	-- Reset accumulator
	content_accumulator = ""
end

return M