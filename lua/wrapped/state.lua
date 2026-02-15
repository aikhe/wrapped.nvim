---@class Wrapped.State
---@field xpad integer
---@field ypad integer
---@field heatmap_year integer
---@field first_commit_year? integer
local M = {
  xpad = 2,
  ypad = 1,
  heatmap_year = tonumber(os.date "%Y", 10),
}

return M
