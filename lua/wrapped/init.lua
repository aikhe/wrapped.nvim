local loading = require "wrapped.ui.loading"

local git = require "wrapped.core.git"
local plugins = require "wrapped.core.plugins"
local files = require "wrapped.core.files"
local state = require "wrapped.state"

---@class Wrapped
local M = {}

---@type WrappedConfig
M.config = require("wrapped.config").defaults()

---@param opts? WrappedConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.run()
  ---@type Wrapped.Results
  local results = {}
  local total = 3
  local completed = 0

  loading.open()

  local function check_done()
    completed = completed + 1
    if completed == total then
      require("wrapped.ui.ui").open(
        results.git.commits,
        results.git.total_count,
        plugins.get_count(),
        results.git.first_commit_date,
        results.files,
        results.plugins,
        results.git.config_stats,
        results.git.commit_activity,
        results.git.size_history
      )
      loading.close()
    end
  end

  git.get_all_data_async(state.heatmap_year, function(data)
    results.git = data
    check_done()
  end)

  files.get_stats_async(function(stats)
    results.files = stats
    check_done()
  end)

  plugins.get_history_async(function(history)
    results.plugins = history
    check_done()
  end)
end

return M
