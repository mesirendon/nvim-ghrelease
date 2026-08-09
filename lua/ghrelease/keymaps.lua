-- Installs the plugin's default keymaps. Each action maps to a normal-mode lhs
-- (or false to skip). Applied from setup(); see config.defaults.keymaps.
local M = {}

-- action name -> { fn, desc }. Add entries here as the plugin grows.
local actions = {
	create = {
		fn = function()
			require("ghrelease").create()
		end,
		desc = "GitHub Release: create",
	},
}

--- Apply keymaps from a spec table (action -> lhs). `false`/`nil` installs none.
--- @param spec table|false|nil
function M.apply(spec)
	if type(spec) ~= "table" then
		return
	end
	for name, def in pairs(actions) do
		local lhs = spec[name]
		if lhs and lhs ~= "" then
			vim.keymap.set("n", lhs, def.fn, { desc = def.desc, silent = true, noremap = true })
		end
	end
end

return M
