-- Pure semantic-version helpers. No Neovim dependencies so this module can be
-- exercised from a headless Lua runner.
local M = {}

--- Parse a semver-ish tag such as "v1.2.3" or "1.2.3-rc.1".
--- @param tag string|nil
--- @return table|nil parsed { prefix, major, minor, patch, pre } or nil
function M.parse(tag)
	if type(tag) ~= "string" then
		return nil
	end
	local prefix, major, minor, patch, pre = tag:match("^(v?)(%d+)%.(%d+)%.(%d+)(.*)$")
	if not major then
		return nil
	end
	return {
		prefix = prefix,
		major = tonumber(major),
		minor = tonumber(minor),
		patch = tonumber(patch),
		pre = pre ~= "" and pre or nil,
	}
end

--- Render a parsed version back to a tag string.
--- @param p table
--- @return string
function M.tostring(p)
	return string.format("%s%d.%d.%d", p.prefix or "", p.major, p.minor, p.patch)
end

--- Bump a parsed version by kind. Lower fields reset. Any pre-release suffix is
--- dropped for a clean release tag.
--- @param p table parsed version
--- @param kind "major"|"minor"|"patch"|"prerelease"
--- @return string tag
function M.bump(p, kind)
	local n = {
		prefix = p.prefix,
		major = p.major,
		minor = p.minor,
		patch = p.patch,
	}
	if kind == "major" then
		n.major, n.minor, n.patch = n.major + 1, 0, 0
	elseif kind == "minor" then
		n.minor, n.patch = n.minor + 1, 0
	elseif kind == "prerelease" then
		-- Next patch marked as an rc pre-release.
		return string.format("%s%d.%d.%d-rc.1", n.prefix or "", n.major, n.minor, n.patch + 1)
	else -- patch (default)
		n.patch = n.patch + 1
	end
	return M.tostring(n)
end

--- Build the list of bump candidates shown in the select menu.
--- @param latest_tag string|nil the latest existing release tag (nil for first release)
--- @return table[] candidates list of { kind, tag, label }
function M.suggest(latest_tag)
	local p = M.parse(latest_tag)
	if not p then
		-- No parseable prior tag: only custom entry is meaningful.
		return {}
	end
	local kinds = { "patch", "minor", "major", "prerelease" }
	local out = {}
	for _, kind in ipairs(kinds) do
		local tag = M.bump(p, kind)
		table.insert(out, { kind = kind, tag = tag, label = string.format("%-11s → %s", kind, tag) })
	end
	return out
end

return M
