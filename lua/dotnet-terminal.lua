local M = {}

local notify_error = function(msg)
	vim.schedule(function()
		vim.notify(msg, vim.log.levels.ERROR)
	end)
end

local is_job_alive = function(job_id)
	if not job_id then
		return false
	end
	local status = vim.fn.jobwait({ job_id }, 0)[1]
	return status == -1
end

local terminal_windows = {}

local function open_terminal(cmd, csproj_path)
	local key = csproj_path
	local existing = terminal_windows[key]

	if existing then
		if is_job_alive(existing.job_id) and vim.api.nvim_win_is_valid(existing.win) then
			vim.api.nvim_win_close(existing.win, true)
			terminal_windows[key] = nil
			return
		else
			terminal_windows[key] = nil
		end
	end

	local first_term_win = nil
	for _, v in pairs(terminal_windows) do
		if vim.api.nvim_win_is_valid(v.win) then
			first_term_win = v.win
			break
		end
	end

	if not first_term_win then
		vim.cmd("botright split")
		vim.cmd("resize 15")
		first_term_win = vim.api.nvim_get_current_win()
		vim.cmd("setlocal winfixheight")
	else
		vim.api.nvim_set_current_win(first_term_win)
		vim.cmd("vsplit")
		vim.cmd("vertical resize 80")
		vim.cmd("setlocal winfixwidth")
	end

	local term_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(term_buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(term_buf, "filetype", "terminal")
	vim.api.nvim_buf_set_option(term_buf, "scrollback", 10000)

	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, term_buf)

	local job_id = vim.fn.termopen(cmd .. " " .. csproj_path, {
		on_exit = function(_, code, _)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(term_buf) then
					vim.api.nvim_buf_delete(term_buf, { force = true })
				end
				terminal_windows[key] = nil
				if code ~= 0 then
					notify_error("Terminal exited with error code " .. code)
				end
			end)
		end,
	})

	terminal_windows[key] = { buf = term_buf, win = win, job_id = job_id }

	vim.api.nvim_set_current_win(win)
	vim.cmd("startinsert")
end

local is_valid_csproj = function(path)
	return path and path:match("%.csproj$")
end

local pick_csproj = function(csproj_files, callback)
	vim.ui.select(csproj_files, {
		prompt = "Select a .csproj file",
		format_item = function(item)
			local filename = vim.fn.fnamemodify(item, ":t")
			return "󰈙 " .. filename:gsub("%.csproj$", "")
		end,
	}, function(choice)
		if is_valid_csproj(choice) then
			vim.g.dotnet_utils.last_used_csproj = choice
			callback(choice)
		else
			notify_error("Invalid .csproj selection")
		end
	end)
end

local get_all_csproj = function()
	local ok, scandir = pcall(require, "plenary.scandir")
	if not ok then
		notify_error("plenary not installed")
		return {}
	end

	local cwd = vim.fn.getcwd():gsub("\\", "/")
	local csproj_files = scandir.scan_dir(cwd, {
		hidden = false,
		only_dirs = false,
		depth = 5,
		search_pattern = "%.csproj$",
	})

	if #csproj_files == 0 then
		notify_error("No .csproj files found in workspace")
		return {}
	end

	return vim.tbl_map(function(path)
		return path:gsub("\\", "/")
	end, csproj_files)
end

local execute = function(cmd)
	local last = vim.g.dotnet_utils.last_used_csproj

	if last and last ~= "" then
		open_terminal(cmd, last)
	else
		local csproj_files = get_all_csproj()
		if #csproj_files > 0 then
			pick_csproj(csproj_files, function(choice)
				if choice then
					vim.g.dotnet_utils.last_used_csproj = choice
					open_terminal(cmd, choice)
				else
					notify_error("Invalid .csproj selection")
				end
			end)
		else
			notify_error("No .csproj files found")
		end
	end
end

function M.build()
	execute("dotnet build --project")
end

function M.watch()
	execute("dotnet watch --project")
end

function M.reset()
	vim.g.dotnet_utils.last_used_csproj = nil
	vim.notify("Cleared last selected .csproj", vim.log.levels.INFO)
end

function M.setup()
	vim.g.dotnet_utils = {
		last_used_csproj = nil,
	}

	vim.keymap.set("n", "<leader>rb", M.build, { desc = "Build project", noremap = true })
	vim.keymap.set("n", "<leader>rc", M.watch, { desc = "Watch project", noremap = true })
	vim.keymap.set("n", "<leader>rr", M.reset, { desc = "Reset selected project", noremap = true })
end

return M
