package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local gh = require("ghrelease.gh")

local failures = 0
local function eq_list(got, want, label)
	if not vim.deep_equal(got, want) then
		failures = failures + 1
		io.write(string.format("FAIL  %-28s got=%s want=%s\n", label, vim.inspect(got), vim.inspect(want)))
	else
		io.write(string.format("ok    %-28s %s\n", label, vim.inspect(got)))
	end
end

-- build_release_cmd ---------------------------------------------------------
local cases = {
	{
		opts = { tag = "v1.3.2", overwrite = false, tag_exists_locally = false },
		want = { "gh", "release", "create", "v1.3.2" },
		label = "pure creation",
	},
	{
		opts = { tag = "v1.3.2", overwrite = false, tag_exists_locally = true },
		want = { "gh", "release", "create", "v1.3.2", "--verify-tag" },
		label = "verify tag",
	},
	{
		opts = { tag = "v1.3.2", overwrite = true, tag_exists_locally = false },
		want = { "gh", "release", "edit", "v1.3.2" },
		label = "edit no local tag",
	},
	{
		opts = { tag = "v1.3.2", overwrite = true, tag_exists_locally = true },
		want = { "gh", "release", "edit", "v1.3.2" },
		label = "edit, ignores verify tag",
	},
}

for _, case in ipairs(cases) do
	eq_list(gh.build_release_cmd(case.opts), case.want, case.label)
end

return failures
