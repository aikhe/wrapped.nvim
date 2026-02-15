---@class Wrapped
local M = {}

---@type WrappedConfig
M.config = require("wrapped.config").defaults()

---@param opts? WrappedConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.run()
  local git = require "wrapped.core.git"
  local plugins = require "wrapped.core.plugins"
  local files = require "wrapped.core.files"
  local state = require "wrapped.state"

  require("wrapped.ui.ui").open(
    git.get_commits(),
    git.get_total_count(),
    plugins.get_count(),
    git.get_first_commit_date(),
    files.get_stats(),
    plugins.get_history(),
    git.get_config_stats(),
    git.get_commit_activity(state.heatmap_year),
    git.get_size_history()
  )
end

return M
