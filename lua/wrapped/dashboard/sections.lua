local api = vim.api
local voltui = require "volt.ui"
local state = require "wrapped.state"

---@class Wrapped.UI.Sections
local M = {}

---@param str string
---@param max integer
---@return string
local function truncate(str, max)
  if str:len() > max then return str:sub(1, max - 3) .. "..." end
  return str
end

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

-- oldest/newest plugin + biggest/smallest file tables
---@param plugin_history Wrapped.PluginHistory
---@param file_stats Wrapped.FileStats
---@return string[][][] section
function M.plugins_files(plugin_history, file_stats)
  local width = state.config.size.width - state.xpad * 2
  local barlen = math.floor((width - 2) / 2) + 2
  local table_w = math.floor((barlen - 2) / 2)

  local function plugin_table(title, name, date)
    local data = {
      { { { truncate(name or "None", table_w - 2), "Normal" } } },
      { { { date and os.date("%Y-%m-%d", date) or "None", "Comment" } } },
    }
    return voltui.table(data, table_w, "normal", { title, "WrappedTitle" })
  end

  local oldest = plugin_history and plugin_history.oldest_plugin
  local newest = plugin_history and plugin_history.newest_plugin

  local oldest_tbl = plugin_table(
    "󰐱  Oldest Unupdated Plugin",
    oldest and oldest.name,
    oldest and oldest.date
  )
  oldest_tbl[1][1][2] = "WrappedBlue0"

  local newest_tbl = plugin_table(
    "  Newest Updated Plugin",
    newest and newest.name,
    newest and newest.date
  )
  newest_tbl[1][1][2] = "WrappedGreen0"

  local left = voltui.grid_col {
    { lines = oldest_tbl, w = table_w + 1, pad = 0 },
    { lines = newest_tbl, w = barlen - table_w - 2 },
  }

  local b = file_stats.biggest
  local s = file_stats.smallest

  local file_tbl = voltui.table({
    {
      {
        { truncate(b.name or "None", barlen - 20), "Normal" },
        { " - ", "Comment" },
        { (b.lines or 0) .. " lines", "Comment" },
      },
    },
    {
      {
        { truncate(s.name or "None", barlen - 20), "Normal" },
        { " - ", "Comment" },
        { (s.lines or 0) .. " lines", "Comment" },
      },
    },
  }, barlen - 2, "normal", { "  Biggest & smallest file", "WrappedYellow0" })

  return voltui.grid_col {
    { lines = left, w = barlen, pad = 0 },
    { lines = file_tbl, w = barlen },
  }
end

-- top 5 file types and top 5 files
---@param file_stats Wrapped.FileStats
---@param width integer
---@return string[][][] section
function M.top_files(file_stats, width)
  local col_w = math.floor((width - 1) / 2)

  local type_data = { { "  Extension", " Lines" } }
  for i, stat in ipairs(file_stats.lines_by_type) do
    if i > 5 then break end
    table.insert(type_data, { stat.name, tostring(stat.lines) })
  end

  local file_data = { { "  File", " Lines" } }
  for i, stat in ipairs(file_stats.top_files or {}) do
    if i > 5 then break end
    local name = vim.fn.fnamemodify(stat.name, ":t")
    table.insert(
      file_data,
      { truncate(name, col_w - 14), tostring(stat.lines) }
    )
  end

  return voltui.grid_col {
    { lines = voltui.table(type_data, col_w, "Special"), w = col_w, pad = 1 },
    { lines = voltui.table(file_data, col_w, "Special"), w = col_w },
  }
end

-- highest/lowest/streak combined table
---@param config_stats Wrapped.ConfigStats
---@param width integer
---@return string[][][] section
function M.streak_table(config_stats, width)
  local hi_day = config_stats.highest_day
  local lo_day = config_stats.lowest_day
  if not hi_day or not lo_day then return {} end

  local streak_start = config_stats.longest_streak_start or "None"
  local streak_end = config_stats.longest_streak_end or "None"

  local h_header = "  Highest"
  local l_header = "  Lowest"
  local s_header = "󰃭  Streak"
  local h_data = hi_day.count .. " (" .. hi_day.date .. ")"
  local l_data = lo_day.count .. " (" .. lo_day.date .. ")"
  local s_data = streak_start .. " to " .. streak_end

  local get_w = api.nvim_strwidth
  local max_w = math.max(
    get_w(h_header),
    get_w(l_header),
    get_w(s_header),
    get_w(h_data),
    get_w(l_data),
    get_w(s_data)
  )

  local function pad(s)
    local d = max_w - get_w(s)
    local left = math.floor(d / 2)
    return string.rep(" ", left) .. s .. string.rep(" ", d - left)
  end

  return voltui.table({
    { pad(h_header), pad(l_header), pad(s_header) },
    { pad(h_data), pad(l_data), pad(s_data) },
  }, width, "WrappedRed0")
end

return M
