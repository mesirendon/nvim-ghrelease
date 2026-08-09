-- Registers the :GhRelease command. Guarded so it loads only once, and lazily
-- requires the core module so start-up cost is nil until the command runs.
if vim.g.loaded_ghrelease then
	return
end
vim.g.loaded_ghrelease = true

if vim.fn.has("nvim-0.10") == 0 then
	vim.notify("nvim-ghrelease requires Neovim 0.10+ (needs vim.system)", vim.log.levels.ERROR)
	return
end

vim.api.nvim_create_user_command("GhRelease", function()
	require("ghrelease").create()
end, {
	desc = "Create a GitHub release interactively via the gh CLI",
})
