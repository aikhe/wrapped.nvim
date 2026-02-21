local voltui = require "volt.ui"
local state = require "wrapped.state"

---@class Wrapped.UI.Bars
local M = {}

-- 4 progress bars: commits, plugins, ever installed, total lines
---@param total_commits integer|string
---@param plugin_count integer
---@param total_ever integer
---@param total_lines integer
---@return string[][][] bars
function M.stats_bars(total_commits, plugin_count, total_ever, total_lines)
  local cap = state.config.cap
  local width = state.config.size.width - state.xpad * 2
  local barlen = math.floor((width - 2) / 2)
  local table_w = math.floor((barlen - 2) / 2)

  ---@param label string
  ---@param val integer|string
  ---@param goal integer
  ---@param icon string
  ---@param hl string
  local function bar(label, val, goal, icon, hl)
    val = tonumber(val) or 0
    local perc = math.min(math.floor((val / goal) * 100), 100)
    return {
      {
        { icon .. " ", hl },
        { label .. " ~ ", hl },
        { val .. " / " .. goal, hl },
      },
      {},
      voltui.progressbar {
        w = table_w,
        val = perc,
        icon = { on = "┃", off = "┃" },
        hl = { on = hl, off = "Linenr" },
      },
    }
  end

  local left = voltui.grid_col {
    {
      lines = bar(
        "  Commits",
        total_commits,
        cap.commits,
        "",
        "WrappedGreen0"
      ),
      w = table_w + 1,
      pad = 2,
    },
    {
      lines = bar("  Plugins", plugin_count, cap.plugins, "", "Special"),
      w = barlen - table_w - 1,
    },
  }
  local right = voltui.grid_col {
    {
      lines = bar(
        "  Total Ever",
        total_ever,
        cap.plugins_ever,
        "",
        "WrappedBlue0"
      ),
      w = table_w + 1,
      pad = 2,
    },
    {
      lines = bar("  Lines", total_lines, cap.lines, "", "WrappedRed0"),
      w = barlen - table_w - 1,
    },
  }

  return voltui.grid_col {
    { lines = left, w = barlen, pad = 2 },
    { lines = right, w = barlen },
  }
end

return M
