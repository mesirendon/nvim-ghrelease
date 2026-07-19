-- User-facing configuration with sane defaults.
local M = {}

M.defaults = {
  -- How many existing releases to show in the context view.
  list_limit = 30,
  -- Default highlighted bump in the version menu.
  default_bump = "patch",
  -- Prefix used when suggesting the very first release tag.
  tag_prefix = "v",
  -- Seed tag when a repository has no releases yet.
  first_tag = "v0.1.0",
  -- Window style for the per-step buffers: "split" | "vsplit" | "float".
  win = "float",
  -- Height (split) / rows (float) for the editing buffers.
  height = 12,
  -- Default keymaps installed by setup(). Each value is the normal-mode lhs
  -- for that action, or false to skip it. Set `keymaps = false` to install
  -- none. Defaults match the `<leader>g` (git) family from a LazyVim config.
  keymaps = {
    create = "<leader>gr", -- :GhRelease
  },
}

M.options = vim.deepcopy(M.defaults)

--- Merge user options over the defaults.
--- @param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
