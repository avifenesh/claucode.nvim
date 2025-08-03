local M = {}

local popup_buf = nil
local popup_win = nil
local progress_win = nil
local progress_buf = nil
local stream_win = nil
local stream_buf = nil
local content_accumulator = ""
local message_windows = {} -- Track multiple message windows
local auto_close_timer = nil
local current_message_index = 0

function M.create_message_window(content, duration)
	duration = duration or 3000 -- Default 3 seconds

	-- Create a new buffer for this message
	local msg_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(msg_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(msg_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(msg_buf, "filetype", "markdown")

	-- Set content
	local lines = vim.split(content, "\n")
	vim.api.nvim_buf_set_lines(msg_buf, 0, -1, false, lines)

	-- Calculate window size based on content
	local width = math.min(80, math.max(40, #content))
	local height = math.min(20, #lines + 2)

	-- Position windows in a cascade or stack
	local row_offset = (current_message_index % 5) * 3
	local col_offset = (current_message_index % 5) * 5

	-- Create window
	local msg_win = vim.api.nvim_open_win(msg_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = 5 + row_offset,
		col = 10 + col_offset,
		style = "minimal",
		border = "rounded",
		title = string.format(" Claude Message %d ", current_message_index + 1),
		title_pos = "center",
		focusable = true,
	})

	-- Set window options
	vim.api.nvim_win_set_option(msg_win, "wrap", true)
	vim.api.nvim_win_set_option(msg_win, "linebreak", true)

	-- Store window info
	local window_info = {
		win = msg_win,
		buf = msg_buf,
		index = current_message_index,
	}
	table.insert(message_windows, window_info)
	current_message_index = current_message_index + 1

	-- Auto-close after duration
	vim.defer_fn(function()
		if vim.api.nvim_win_is_valid(msg_win) then
			vim.api.nvim_win_close(msg_win, true)
		end
		-- Remove from tracking
		for i, win_info in ipairs(message_windows) do
			if win_info.win == msg_win then
				table.remove(message_windows, i)
				break
			end
		end
	end, duration)

	return msg_win
end

function M.show_response(content)
	-- Create buffer if it doesn't exist
	if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
		popup_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(popup_buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(popup_buf, "swapfile", false)
		vim.api.nvim_buf_set_option(popup_buf, "filetype", "markdown")
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
	vim.api.nvim_win_set_option(popup_win, "wrap", true)
	vim.api.nvim_win_set_option(popup_win, "linebreak", true)

	-- Add keymaps for the popup
	local opts = { noremap = true, silent = true, buffer = popup_buf }
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", opts)

	-- Scroll to top
	vim.api.nvim_win_set_cursor(popup_win, { 1, 0 })
end

function M.append_to_response(content)
	if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
		M.show_response(content)
		return
	end

	-- Append to existing buffer
	local lines = vim.split(content, "\n")
	local line_count = vim.api.nvim_buf_line_count(popup_buf)
	vim.api.nvim_buf_set_lines(popup_buf, line_count, line_count, false, lines)
end

function M.close_popup()
	if popup_win and vim.api.nvim_win_is_valid(popup_win) then
		vim.api.nvim_win_close(popup_win, true)
	end
	popup_win = nil
end

function M.show_progress(message)
	-- Create progress buffer if needed
	if not progress_buf or not vim.api.nvim_buf_is_valid(progress_buf) then
		progress_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(progress_buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(progress_buf, "swapfile", false)
	end

	-- Update progress message (split by newlines)
	local lines = vim.split(message, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, lines)

	-- Create or update progress window
	if not progress_win or not vim.api.nvim_win_is_valid(progress_win) then
		local width = math.min(60, #message + 4)
		local height = #lines

		progress_win = vim.api.nvim_open_win(progress_buf, false, {
			relative = "editor",
			width = width,
			height = height,
			row = vim.o.lines - 3,
			col = vim.o.columns - width - 2,
			style = "minimal",
			border = "single",
			focusable = false,
		})
	end
end

function M.hide_progress()
	if progress_win and vim.api.nvim_win_is_valid(progress_win) then
		vim.api.nvim_win_close(progress_win, true)
		progress_win = nil
	end
end

function M._create_streaming_popup()
	-- Create buffer if it doesn't exist
	if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
		popup_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(popup_buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(popup_buf, "swapfile", false)
		vim.api.nvim_buf_set_option(popup_buf, "filetype", "markdown")
	end

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
	popup_win = vim.api.nvim_open_win(popup_buf, false, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Claude Response (Streaming) ",
		title_pos = "center",
	})

	-- Set window options
	vim.api.nvim_win_set_option(popup_win, "wrap", true)
	vim.api.nvim_win_set_option(popup_win, "linebreak", true)

	-- Add keymaps for the popup
	local opts = { noremap = true, silent = true, buffer = popup_buf }
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", opts)
end

function M._create_stream_window()
	-- Create stream buffer if it doesn't exist
	if not stream_buf or not vim.api.nvim_buf_is_valid(stream_buf) then
		stream_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(stream_buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(stream_buf, "swapfile", false)
		vim.api.nvim_buf_set_option(stream_buf, "filetype", "markdown")
	end

	-- Calculate window dimensions - bottom right corner
	local width = math.min(60, math.floor(vim.o.columns * 0.4))
	local height = math.min(20, math.floor(vim.o.lines * 0.3))

	-- Position in bottom right
	local row = vim.o.lines - height - 3
	local col = vim.o.columns - width - 2

	-- Create stream window
	stream_win = vim.api.nvim_open_win(stream_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Claude Streaming ",
		title_pos = "center",
		focusable = false,
	})

	-- Set window options
	vim.api.nvim_win_set_option(stream_win, "wrap", true)
	vim.api.nvim_win_set_option(stream_win, "linebreak", true)
end

function M.start_streaming()
	content_accumulator = ""
	-- Reset message index for new conversation
	current_message_index = 0
	-- Clear any existing message windows
	for _, win_info in ipairs(message_windows) do
		if vim.api.nvim_win_is_valid(win_info.win) then
			vim.api.nvim_win_close(win_info.win, true)
		end
	end
	message_windows = {}
	M.show_progress("🤔 Claude is thinking...")
end

local message_buffer = ""
local message_delimiter = "\n\n" -- Detect paragraph breaks as message boundaries

function M.stream_content(text)
	content_accumulator = content_accumulator .. text
	message_buffer = message_buffer .. text

	-- Check for complete messages (paragraphs)
	local messages = vim.split(message_buffer, message_delimiter, { plain = true })

	-- If we have more than one part, we have at least one complete message
	if #messages > 1 then
		-- Show all complete messages except the last (which might be incomplete)
		for i = 1, #messages - 1 do
			local msg = vim.trim(messages[i])
			if msg ~= "" then
				-- Create a message window with appropriate duration based on length
				local read_time = math.max(3000, math.min(10000, #msg * 50)) -- 50ms per char, 3-10 seconds
				M.create_message_window(msg, read_time)
			end
		end

		-- Keep only the last (potentially incomplete) part in the buffer
		message_buffer = messages[#messages]
	end

	-- Update progress to show we're receiving data
	local char_count = #content_accumulator
	local message = string.format("💭 Claude is responding... (%d chars)", char_count)
	M.show_progress(message)
end

function M.on_tool_use(tool_data)
	local tool_name = tool_data.name or "unknown"
	local message = string.format("🔧 Using %s...", tool_name)

	-- Add specific messages for common tools
	if tool_name == "Edit" then
		local file = tool_data.input and tool_data.input.file_path or "file"
		message = string.format("✏️  Editing %s...", vim.fn.fnamemodify(file, ":t"))
	elseif tool_name == "Write" then
		local file = tool_data.input and tool_data.input.file_path or "file"
		message = string.format("📝 Writing %s...", vim.fn.fnamemodify(file, ":t"))
	elseif tool_name == "Read" then
		local file = tool_data.input and tool_data.input.file_path or "file"
		message = string.format("📖 Reading %s...", vim.fn.fnamemodify(file, ":t"))
	elseif tool_name == "Bash" then
		local cmd = tool_data.input and tool_data.input.command or "command"
		-- Truncate long commands
		if #cmd > 40 then
			cmd = cmd:sub(1, 37) .. "..."
		end
		message = string.format("🖥️  Running: %s", cmd)
	end

	M.show_progress(message)
end

function M.close_stream_window()
	if stream_win and vim.api.nvim_win_is_valid(stream_win) then
		vim.api.nvim_win_close(stream_win, true)
	end
	stream_win = nil
end

function M.finish_streaming()
	M.hide_progress()

	-- Show any remaining message in the buffer
	if message_buffer and vim.trim(message_buffer) ~= "" then
		local read_time = math.max(3000, math.min(10000, #message_buffer * 50))
		M.create_message_window(vim.trim(message_buffer), read_time)
	end

	-- Reset buffers
	message_buffer = ""

	-- Don't show the full response in a popup anymore - messages are shown individually
	-- Just notify completion
	vim.notify("Claude response complete", vim.log.levels.INFO)
end

return M
