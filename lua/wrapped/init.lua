---@class Wrapped
local M = {}

local state = require "wrapped.state"
local git = require "wrapped.core.git"
local plugins = require "wrapped.core.plugins"
local files = require "wrapped.core.files"
local loading = require "wrapped.ui.loading"

---@param opts? WrappedConfig
M.setup = function(opts)
  state.config = vim.tbl_deep_extend("force", state.config, opts or {})
  
  -- Auto-detect: use current directory if no path specified
  if not state.config.path or state.config.path == "" then
    state.config.path = vim.fn.getcwd() -- auto-detect current directory
  end

  -- Set up keybindings
  local keys = state.config.keys
  if keys and keys.open and keys.open ~= "<leader>gw" then
    -- User customized: remove default and set custom
    vim.keymap.del("n", "<leader>gw")
    vim.keymap.set("n", keys.open, ":WrappedNvim<CR>", { desc = "Open Wrapped dashboard" })
  end
end

M.run = function()
  ---@type Wrapped.Results
  local results = {}
  local total = 3
  local done = 0

  loading.open()

  local function check()
    done = done + 1
    if done == total then
      require("wrapped.ui").open(results)
      loading.close()
    end
  end

  git.get_all_data_async(state.heatmap_year, function(data)
    results.git = data
    check()
  end)

  files.get_stats_async(function(stats)
    results.files = stats
    check()
  end)

  plugins.get_history_async(function(history)
    results.plugins = history
    check()
  end)
end

return M
