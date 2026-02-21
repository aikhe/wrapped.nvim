local api = vim.api

---@class Wrapped.State
local M = {
  -- user config
  config = {
    path = vim.fn.stdpath "config",
    border = false,
    size = { width = 120, height = 40 },
    exclude_filetype = { ".gitmodules" },
    cap = {
      commits = 1000,
      plugins = 100,
      plugins_ever = 200,
      lines = 10000,
    },
  },

  -- layout
  xpad = 2,
  ypad = 1,

  -- ui runtime
  ns = api.nvim_create_namespace "WrappedUI",
  buf = nil,
  win = nil,
  commit_activity = nil,
  heatmap_year = tonumber(os.date "%Y", 10),
  first_commit_year = nil,
}

return M
