-- Public API for nvim-ghrelease.
local config = require("ghrelease.config")

local M = {}

--- Merge user options and install default keymaps. Optional — the command
--- works without calling setup(), but default keymaps require it.
--- @param opts table|nil
function M.setup(opts)
  config.setup(opts)
  require("ghrelease.keymaps").apply(config.options.keymaps)
  return M
end

--- Start the interactive release-creation flow.
function M.create()
  require("ghrelease.flow").run()
end

return M
