-- Async wrappers around the `gh` and `git` CLIs. Every function is callback
-- based so the flow coroutine can yield on each call. Callbacks always run on
-- the main loop (via vim.schedule) so they may touch the editor safely.
local M = {}

--- Run a command asynchronously.
--- @param cmd string[]
--- @param cb fun(ok: boolean, stdout: string, stderr: string)
local function run(cmd, cb)
	vim.system(cmd, { text = true }, function(res)
		vim.schedule(function()
			cb(res.code == 0, (res.stdout or ""), (res.stderr or ""))
		end)
	end)
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Verify gh is installed, authenticated, and we are inside a GitHub repo.
--- @param cb fun(ok: boolean, err: string|nil)
function M.check(cb)
	if vim.fn.executable("gh") == 0 then
		return cb(false, "`gh` CLI not found on PATH. Install it: https://cli.github.com")
	end
	run({ "gh", "auth", "status" }, function(ok, _, stderr)
		if not ok then
			return cb(false, "gh is not authenticated. Run `gh auth login`.\n" .. trim(stderr))
		end
		run({ "gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner" }, function(ok2, _, stderr2)
			if not ok2 then
				return cb(false, "Not inside a GitHub repository (or no origin remote).\n" .. trim(stderr2))
			end
			cb(true, nil)
		end)
	end)
end

--- List existing releases as plain text for the context view.
--- @param limit integer
--- @param cb fun(text: string)
function M.list(limit, cb)
	run({ "gh", "release", "list", "--limit", tostring(limit) }, function(ok, out, stderr)
		if not ok then
			cb("No releases found (or unable to list).\n" .. trim(stderr))
		elseif trim(out) == "" then
			cb("No releases yet — this will be the first release.")
		else
			cb(out)
		end
	end)
end

--- Resolve the latest release tag. Falls back to the newest git tag, then nil.
--- @param cb fun(tag: string|nil)
function M.latest_tag(cb)
	run({ "gh", "release", "view", "--json", "tagName", "-q", ".tagName" }, function(ok, out)
		local tag = trim(out)
		if ok and tag ~= "" then
			return cb(tag)
		end
		run({ "git", "describe", "--tags", "--abbrev=0" }, function(ok2, out2)
			local gtag = trim(out2)
			cb(ok2 and gtag ~= "" and gtag or nil)
		end)
	end)
end

--- Checks whether a release/tag already exists for `tag`
--- @param tag string
--- @param cb fun(release_exists: boolean, local_tag_exists: boolean)
function M.tag_status(tag, cb)
	run({ "gh", "release", "view", tag }, function(ok)
		if ok then
			run({ "git", "rev-parse", "--verify", "--quiet", "refs/tags/" .. tag }, function(ok2)
				return cb(ok, ok2)
			end)
		else
			return cb(ok, false)
		end
	end)
end

--- Fetch GitHub's auto-generated release notes for a tag.
--- @param tag string
--- @param prev string|nil previous tag to diff from
--- @param cb fun(body: string)
function M.generated_notes(tag, prev, cb)
	run({ "gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner" }, function(ok, out)
		local repo = trim(out)
		if not ok or repo == "" then
			return cb("")
		end
		local cmd = {
			"gh",
			"api",
			"--method",
			"POST",
			string.format("repos/%s/releases/generate-notes", repo),
			"-f",
			"tag_name=" .. tag,
		}
		if prev and prev ~= "" then
			vim.list_extend(cmd, { "-f", "previous_tag_name=" .. prev })
		end
		vim.list_extend(cmd, { "-q", ".body" })
		run(cmd, function(ok2, out2)
			cb(ok2 and out2 or "")
		end)
	end)
end

--- Commit log since the previous tag, formatted as a bullet list.
--- @param prev string|nil
--- @param cb fun(body: string)
function M.commit_log(prev, cb)
	local range = (prev and prev ~= "") and (prev .. "..HEAD") or "HEAD"
	run({ "git", "log", range, "--pretty=format:- %s" }, function(ok, out)
		cb(ok and out or "")
	end)
end

--- Create the release.
--- @param opts table { tag, title, notes, prerelease, draft, overwrite, tag_exists_locally }
--- @param cb fun(ok: boolean, output: string)
function M.create(opts, cb)
	local cmd = M.build_release_cmd({
		tag = opts.tag,
		overwrite = opts.overwrite,
		tag_exists_locally = opts.tag_exists_locally,
	})

	if opts.title and opts.title ~= "" then
		vim.list_extend(cmd, { "--title", opts.title })
	end

	local notes_file
	if opts.notes and opts.notes ~= "" then
		local path = vim.fn.tempname()
		local fd = io.open(path, "w")
		if fd then
			fd:write(opts.notes)
			fd:close()
			notes_file = path
			vim.list_extend(cmd, { "--notes-file", notes_file })
		else
			-- Could not write the temp file: pass the notes inline so gh still
			-- receives a body instead of erroring on missing notes in a non-TTY.
			vim.list_extend(cmd, { "--notes", opts.notes })
		end
	else
		vim.list_extend(cmd, { "--notes", "" })
	end

	if opts.prerelease then
		table.insert(cmd, "--prerelease")
	end
	if opts.draft then
		table.insert(cmd, "--draft")
	end

	run(cmd, function(ok, out, stderr)
		if notes_file then
			os.remove(notes_file)
		end
		cb(ok, ok and trim(out) or trim(stderr))
	end)
end

--- @param opts table { tag, overwrite, tag_exists_locally }
--- @return table commands
function M.build_release_cmd(opts)
	local cmds = { "gh", "release" }
	if opts.overwrite then
		return vim.list_extend(cmds, { "edit", opts.tag })
	end

	vim.list_extend(cmds, { "create", opts.tag })
	if opts.tag_exists_locally then
		vim.list_extend(cmds, { "--verify-tag" })
	end

	return cmds
end

return M
