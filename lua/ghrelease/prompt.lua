-- UI primitives: a save-and-close editing buffer per step, choice menus, and a
-- read-only context viewer. All are callback based; flow.lua adapts them to the
-- coroutine via `await`.
local config = require("ghrelease.config")

local M = {}

--- Open a window for a scratch buffer according to the configured style, with
--- `hint` shown as the float's border title (floats) or the winbar (splits).
--- Floats keep `style = "minimal"` off so the title renders reliably.
--- @param buf integer
--- @param hint string
--- @return integer win
local function open_window(buf, hint)
	local opts = config.options
	if opts.win == "float" then
		local width = math.floor(vim.o.columns * 0.7)
		local height = opts.height
		local win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = math.floor((vim.o.lines - height) / 2 - 1),
			col = math.floor((vim.o.columns - width) / 2),
			border = "rounded",
			title = " " .. hint .. " ",
			title_pos = "center",
		})
		-- Approximate the "minimal" look without suppressing the border title.
		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = "no"
		return win
	elseif opts.win == "vsplit" then
		vim.cmd("botright vsplit")
	else
		vim.cmd("botright split")
		vim.cmd("resize " .. opts.height)
	end
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.wo[win].winbar = "  " .. hint
	return win
end

--- Present an editable buffer. The user edits, then `:w`/`:wq`/`:q`; on window
--- close the current buffer contents are returned.
--- @param spec table { title: string, default: string|nil, filetype: string|nil }
--- @param cb fun(value: string)
function M.buffer_step(spec, cb)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = spec.filetype or "text"
	-- Include the buffer handle so concurrent flows never collide on the name.
	vim.api.nvim_buf_set_name(buf, string.format("ghrelease://%s [%d]", spec.title or "input", buf))

	local default = spec.default or ""
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(default, "\n", { plain = true }))

	open_window(buf, (spec.title or "") .. "   (edit, then :wq to continue — :q keeps what is shown)")
	vim.bo[buf].modified = false

	local group = vim.api.nvim_create_augroup("GhReleaseStep" .. buf, { clear = true })

	-- acwrite buffers need a write handler so :w/:wq do not error.
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		group = group,
		buffer = buf,
		callback = function()
			vim.bo[buf].modified = false
		end,
	})

	-- Content is captured on window close regardless of a save, so keep the
	-- buffer "unmodified" as the user types. This lets `:q` close (and keep what
	-- is shown) instead of raising E37 after edits, matching the hint.
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.bo[buf].modified = false
			end
		end,
	})

	local done = false
	vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWipeout" }, {
		group = group,
		buffer = buf,
		callback = function()
			if done then
				return
			end
			done = true
			local lines = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or {}
			cb((table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")))
		end,
	})

	-- Start editing at the end of the seeded text.
	vim.cmd("normal! G$")
end

--- Choice menu backed by vim.ui.select.
--- @param items any[]
--- @param opts table { prompt: string, format_item: fun(item):string|nil }
--- @param cb fun(choice: any|nil)
function M.select(items, opts, cb)
	vim.ui.select(items, {
		prompt = opts.prompt,
		format_item = opts.format_item,
	}, function(choice)
		cb(choice)
	end)
end

--- Yes/no confirmation.
--- @param prompt string
--- @param cb fun(yes: boolean)
function M.confirm(prompt, cb)
	vim.ui.select({ "No", "Yes" }, { prompt = prompt }, function(choice)
		cb(choice == "Yes")
	end)
end

--- Read-only context view (e.g. the list of existing releases). Any of
--- <CR>/q/<Esc> dismisses it and continues.
--- @param title string
--- @param text string
--- @param cb fun()
function M.context(title, text, cb)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"

	local win = open_window(buf, title .. "   (press <CR>, q or <Esc> to continue)")

	local group = vim.api.nvim_create_augroup("GhReleaseContext" .. buf, { clear = true })

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		cb()
	end

	for _, key in ipairs({ "<CR>", "q", "<Esc>" }) do
		vim.keymap.set("n", key, finish, { buffer = buf, nowait = true, silent = true })
	end

	-- Also resume if the window/buffer is dismissed any other way (:q, <C-w>c,
	-- ZZ, …) so the flow never stalls waiting on a closed window.
	vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWipeout" }, {
		group = group,
		buffer = buf,
		callback = finish,
	})
end

return M
