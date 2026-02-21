local api = vim.api
local volt = require "volt"
local voltui = require "volt.ui"
local highlights = require "wrapped.ui.highlights"
local state = require "wrapped.state"

---@class Wrapped.Ui
local M = {}
local ui_state = { ---@type Wrapped.UiState
  buf = nil,
  win = nil,
  ns = api.nvim_create_namespace "WrappedUI",
}

---@return WrappedConfig config
local function get_config() return require("wrapped").config end

local function close()
  if ui_state.win then pcall(api.nvim_win_close, ui_state.win, true) end
  if ui_state.buf then
    pcall(api.nvim_buf_delete, ui_state.buf, { force = true })
  end
  ui_state.win, ui_state.buf = nil, nil
end

---@param n integer
---@return string dd
local function dd(n) return n < 10 and "0" .. n or tostring(n) end

---@param str string
---@param max integer
---@return string str
local function truncate(str, max)
  if str:len() > max then return str:sub(1, max - 3) .. "..." end
  return str
end

-- returns intensity index 0 (brightest) to 3 (dimmest)
---@param n integer
---@return "0"|"1"|"2"|"3" intensity
local function get_intensity(n)
  if n > 5 then return "0" end
  if n > 2 then return "1" end
  if n > 0 then return "2" end
  return "3"
end

local month_colors = highlights.month_colors
local color_cycle = vim.list_extend(
  vim.list_extend({}, month_colors),
  vim.list_extend(vim.list_extend({}, month_colors), month_colors)
)

---@param y integer
---@return boolean leap
local function is_leap(y) return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0) end

---@param activity table<string, integer>
---@param width integer
---@return string[][][] heatmap
local function build_heatmap(activity, width)
  local year = state.heatmap_year
  local months = {
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  }
  local days_in = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if is_leap(year) then days_in[2] = 29 end
  local day_names = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

  -- month header row with per-month color
  ---@type string[][]
  local header = { { " »", "Comment" }, { "  " } }
  for i = 1, 12 do
    table.insert(header, { "  " .. months[i] .. "  ", "Ex" .. color_cycle[i] })
    if i < 12 then table.insert(header, { "  " }) end
  end

  ---@type string[][]
  local sep =
    voltui.separator("─", width - (state.xpad or 0) * 2 - 4, "Comment")
  local lines = { header, sep } ---@type string[][][]

  -- 7 weekday rows
  for d = 1, 7 do
    table.insert(lines, { { day_names[d], "Comment" }, { " │ ", "Comment" } })
  end

  -- fill grid per month
  for m = 1, 12 do
    local start_dow = tonumber(
      os.date("%w", os.time { year = year, month = m, day = 1 }),
      10
    ) + 1

    if m == 1 then
      for n = 1, start_dow - 1 do
        table.insert(lines[n + 2], { "  " })
      end
    end

    local color = color_cycle[m]
    for day = 1, days_in[m] do
      local dow = tonumber(
        os.date("%w", os.time { year = year, month = m, day = day })
      ) + 1
      local count = activity[dd(day) .. dd(m) .. year] or 0
      local hl = count > 0 and ("Wrapped" .. color .. get_intensity(count))
        or "Linenr"
      table.insert(lines[dow + 2], { "󱓻 ", hl })
    end
  end

  voltui.border(lines, "Comment")

  -- legend with green levels (matching typr)
  local legend = { ---@type string[][]
    { "  Commit Activity", "WrappedGreen0" },
    { "  " },
    { "« ", "Comment" },
    { tostring(year), "Special" },
    { " »", "Comment" },
    { "_pad_" },
    { "Less " },
  }
  for i = 3, 0, -1 do
    table.insert(legend, { "󱓻 ", "WrappedGreen" .. i })
  end
  table.insert(legend, { " More" })
  table.insert(lines, 1, voltui.hpad(legend, width - (state.xpad or 0) * 2 - 4))

  return lines
end

---@param size_history Wrapped.SizeHistory
---@param target_width integer
---@return string[][][] size_chart
local function build_size_chart(size_history, target_width)
  local vals = size_history.values
  if #vals == 0 then return {} end

  local min_val = math.min(unpack(vals))
  local max_val = math.max(unpack(vals))
  local diff = max_val - min_val

  -- dynamic baseline to "zoom in" on variation
  local baseline = 0
  if diff > 0 then
    baseline = math.max(0, math.floor(min_val - diff * 0.5))
  else
    baseline = math.max(0, math.floor(min_val * 0.8))
  end

  if max_val == baseline then max_val = baseline + 1 end
  local range = max_val - baseline

  -- normalize to 1-100 scale for bar graph
  local scaled = {} ---@type integer[]
  for _, v in ipairs(vals) do
    table.insert(scaled, math.floor(((v - baseline) / range) * 100))
  end

  -- side labels (~4 chars) + " │ " (3 chars)
  local bar_w, bar_gap = 1, 1
  local bar_area = target_width - 8
  local max_items = math.floor(bar_area / (bar_w + bar_gap))

  -- get the subset of data to display (downsample if too many items)
  local display_vals = scaled
  local num_data = #scaled
  if num_data > max_items then
    display_vals = {}
    -- show beginning and the last by downsampling
    local step = (num_data - 1) / (max_items - 1)
    for i = 0, max_items - 1 do
      local idx = math.floor(1 + i * step + 0.5)
      table.insert(display_vals, scaled[idx])
    end
  end

  local chart_data = {
    val = display_vals,
    footer_label = { "󰉋  Config Size Over Time", "WrappedGreen0" },

    format_labels = function(x)
      local val = math.floor(baseline + (x / 100) * range)
      if val >= 1000 then return string.format("%.1fk", val / 1000) end
      return tostring(val)
    end,

    baropts = {
      w = bar_w,
      gap = bar_gap,
      -- dual_hl = { "WrappedGreen0", "WrappedGreen3" },
      format_hl = function(x) ---@param x integer
        if x > 85 then return "WrappedGreen0" end
        if x > 60 then return "WrappedGreen1" end
        if x > 30 then return "WrappedGreen2" end
        return "WrappedGreen3"
      end,
    },
  }

  local chart = voltui.graphs.bar(chart_data) ---@type string[][][]

  return chart
end

---@param plugin_history Wrapped.PluginHistory
---@param target_width integer
---@return string[][][] growth_chart
local function build_plugin_growth_chart(plugin_history, target_width)
  if not plugin_history then return {} end

  local growth = plugin_history.growth
  if not growth or #growth == 0 then return {} end

  local vals = {}
  for _, entry in ipairs(growth) do
    table.insert(vals, (entry.count or 0))
  end

  local min_val = math.min(unpack(vals))
  local max_val = math.max(unpack(vals))
  local diff = max_val - min_val

  local baseline = 0
  if diff > 5 then baseline = math.max(0, math.floor(min_val - diff * 0.3)) end

  if max_val == baseline then max_val = baseline + 1 end
  local range = max_val - baseline

  local scaled = {}
  for _, v in ipairs(vals) do
    table.insert(
      scaled,
      math.min(100, math.max(0, math.floor(((v - baseline) / range) * 100)))
    )
  end

  local bar_w, bar_gap = 2, 1
  local label_area = 10
  local max_bars = math.floor((target_width - label_area) / (bar_w + bar_gap))
  if max_bars < 1 then max_bars = 1 end

  local display_vals = scaled
  if #scaled ~= max_bars and #scaled > 0 then
    display_vals = {}
    if #scaled == 1 then
      for i = 1, max_bars do
        table.insert(display_vals, scaled[1])
      end
    else
      local step = (#scaled - 1) / (max_bars - 1)
      for i = 0, max_bars - 1 do
        local idx = math.floor(1 + i * step + 0.5)
        table.insert(display_vals, scaled[idx])
      end
    end
  end

  local chart_data = {
    val = display_vals,
    footer_label = { "󰐱  Plugin Growth Overtime", "WrappedBlue0" },
    format_labels = function(x)
      local val = math.floor(baseline + (x / 100) * range)
      return tostring(val)
    end,
    baropts = {
      w = bar_w,
      gap = bar_gap,
      dual_hl = { "WrappedBlue0", "WrappedBlue2" },
    },
  }

  return voltui.graphs.bar(chart_data)
end

---@param commit_history integer[]
---@param target_width integer
---@return string[][][] freq_chart
local function build_commit_freq_chart(commit_history, target_width)
  if not commit_history or #commit_history == 0 then return {} end

  local vals = commit_history

  local max_val = math.max(unpack(vals))
  if max_val == 0 then max_val = 1 end

  local scaled = {}
  for _, v in ipairs(vals) do
    if v <= 0 then
      table.insert(scaled, 0)
    else
      local pct = 20 + math.floor(((v - 1) / math.max(1, max_val - 1)) * 80)
      table.insert(scaled, math.min(100, pct))
    end
  end

  local max_bars = math.floor((target_width - 10) / 3)
  if max_bars < 1 then max_bars = 1 end

  local display_vals = scaled
  if #scaled ~= max_bars and #scaled > 0 then
    display_vals = {}
    if #scaled == 1 then
      for i = 1, max_bars do
        table.insert(display_vals, scaled[1])
      end
    else
      local step = (#scaled - 1) / (max_bars - 1)
      for i = 0, max_bars - 1 do
        local idx = math.floor(1 + i * step + 0.5)
        table.insert(display_vals, scaled[idx])
      end
    end
  end

  local chart_data = {
    val = display_vals,
    width = target_width,
    footer_label = { "󰔵  Config Changes Frequency", "WrappedYellow0" },
    format_labels = function(x)
      if x == 10 then return "0" end
      local val = 1 + math.floor(((x - 20) / 80) * (max_val - 1))
      return tostring(val)
    end,
    baropts = {
      sidelabels = true,
      icons = { on = " 󰄰", off = " ·" },
      hl = { on = "WrappedYellow0", off = "Comment" },
    },
  }

  local chart = voltui.graphs.dot(chart_data)

  -- push chart down to align
  table.insert(chart, 1, { { " ", "" } })

  return chart
end

local function build_stats_bars(
  total_commits,
  total_plugins,
  total_plugins_ever,
  total_lines
)
  local config = get_config()
  local cap = config.cap
  local width = get_config().size.width - (state.xpad or 0) * 2
  local barlen = math.floor((width - 2) / 2)
  local table_w = math.floor((barlen - 2) / 2)

  ---@param label string
  ---@param val? integer
  ---@param goal integer
  ---@param icon string
  ---@param hl string
  ---@return string[][][] bar
  local function build_bar(label, val, goal, icon, hl)
    val = val or 0
    local perc = math.min(math.floor((val / goal) * 100), 100)
    return { ---@type string[][][]
      {
        { icon .. " ", hl },
        { label .. " ~ ", hl },
        { tostring(val) .. " / " .. tostring(goal), hl },
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

  local commit_bars =
    build_bar("  Commits", total_commits, cap.commits, "", "WrappedGreen0")
  local plugin_bars =
    build_bar("  Plugins", total_plugins, cap.plugins, "", "Special")
  local ever_bars = build_bar(
    "  Total Ever",
    total_plugins_ever,
    cap.plugins_ever,
    "",
    "WrappedBlue0"
  )
  local line_bars =
    build_bar("  Lines", total_lines, cap.lines, "", "WrappedRed0")

  local left_bars = voltui.grid_col {
    { lines = commit_bars, w = table_w + 1, pad = 2 },
    { lines = plugin_bars, w = barlen - table_w - 1 },
  }
  local right_bars = voltui.grid_col {
    { lines = ever_bars, w = table_w + 1, pad = 2 },
    { lines = line_bars, w = barlen - table_w - 1 },
  }

  return voltui.grid_col {
    { lines = left_bars, w = barlen, pad = 2 },
    { lines = right_bars, w = barlen },
  }
end

---@param plugin_history Wrapped.PluginHistory
---@param file_stats Wrapped.FileStats
---@return string[][][] plugins_files
local function build_plugins_files_table(plugin_history, file_stats)
  local width = get_config().size.width - (state.xpad or 0) * 2
  local barlen = math.floor((width - 2) / 2) + 2
  local table_w = math.floor((barlen - 2) / 2)

  local function build_plugin_table(title, name, date)
    local truncated_name = truncate(name or "None", table_w - 2)
    local info_date = date
        and (
          os.date("%Y-%m-%d", date) --[[@as string]]
        )
      or "None"
    local data = { ---@type string[][][][]
      { { { truncated_name, "Normal" } } },
      { { { info_date, "Comment" } } },
    }
    return voltui.table(data, table_w, "normal", { title, "WrappedTitle" })
  end

  local oldest = plugin_history and plugin_history.oldest_plugin
  local newest = plugin_history and plugin_history.newest_plugin

  local oldest_tbl = build_plugin_table(
    "󰐱  Oldest Unupdated Plugin",
    oldest and oldest.name,
    oldest and oldest.date
  )
  oldest_tbl[1][1][2] = "WrappedBlue0" -- override title HL

  local newest_tbl = build_plugin_table(
    "  Newest Updated Plugin",
    newest and newest.name,
    newest and newest.date
  )
  newest_tbl[1][1][2] = "WrappedGreen0" -- override title HL

  local left_inner = voltui.grid_col {
    { lines = oldest_tbl, w = table_w + 1, pad = 0 },
    { lines = newest_tbl, w = barlen - table_w - 2 },
  }

  local b_name = truncate(file_stats.biggest.name or "None", barlen - 20)
  local s_name = truncate(file_stats.smallest.name or "None", barlen - 20)
  local b_lines = tostring(file_stats.biggest.lines or 0) .. " lines"
  local s_lines = tostring(file_stats.smallest.lines or 0) .. " lines"

  local file_tbl_data = { ---@type string[][][][]
    { { { b_name, "Normal" }, { " - ", "Comment" }, { b_lines, "Comment" } } },
    { { { s_name, "Normal" }, { " - ", "Comment" }, { s_lines, "Comment" } } },
  }

  local file_tbl = voltui.table(
    file_tbl_data,
    barlen - 2,
    "normal",
    { "  Biggest & smallest file", "WrappedYellow0" }
  )

  return voltui.grid_col {
    { lines = left_inner, w = barlen, pad = 0 },
    { lines = file_tbl, w = barlen },
  }
end

---@param file_stats Wrapped.FileStats
---@param width integer
---@return string[][][] top_files
local function build_top_files_table(file_stats, width)
  local inner_gap = 1
  local col_w = math.floor((width - inner_gap) / 2)

  -- top 5 file types by total lines
  local type_data = { { "  Extension", " Lines" } } ---@type string[][]
  for i, stat in ipairs(file_stats.lines_by_type) do
    if i > 5 then break end
    table.insert(type_data, { stat.name, tostring(stat.lines) })
  end
  local type_tbl = voltui.table(type_data, col_w, "Special")

  -- top 5 individual files by lines
  local file_data = { { "  File", " Lines" } } ---@type string[][]
  for i, stat in ipairs(file_stats.top_files or {}) do
    if i > 5 then break end
    local name = vim.fn.fnamemodify(stat.name, ":t")
    table.insert(
      file_data,
      { truncate(name, col_w - 14), tostring(stat.lines) }
    )
  end
  local file_tbl = voltui.table(file_data, col_w, "Special")

  return voltui.grid_col {
    { lines = type_tbl, w = col_w, pad = inner_gap },
    { lines = file_tbl, w = col_w },
  }
end

---@param lines string[][][]
---@param text string
---@param hl? string
---@return string[][][] lines
local function add(lines, text, hl)
  table.insert(lines, { { text, hl or "Special" } })
  return lines
end

---@param commits string[]
---@param total_count integer|string
---@param plugin_count integer
---@param first_commit_date string
---@param file_stats Wrapped.FileStats
---@param plugin_history Wrapped.PluginHistory
---@param config_stats Wrapped.ConfigStats
---@param size_history Wrapped.SizeHistory
local function build_content(
  commits,
  total_count,
  plugin_count,
  first_commit_date,
  file_stats,
  plugin_history,
  config_stats,
  size_history
)
  local lines = {}

  vim.list_extend(
    lines,
    build_stats_bars(
      total_count,
      plugin_count,
      plugin_history and plugin_history.total_ever_installed or 0,
      file_stats.total_lines
    )
  )
  lines = add(add(lines, " ", ""), " ", "")

  vim.list_extend(lines, build_plugins_files_table(plugin_history, file_stats))

  if config_stats then
    local barlen =
      math.floor((get_config().size.width - (state.xpad or 0) * 2 - 2) / 2)
    local left_tbl = {
      { "  Sessions", "  Time" },
      { "Streak", tostring(config_stats.longest_streak) .. " days" },
      { "Last Change", config_stats.last_change },
    }
    local right_tbl = {
      { "  History", "󰌵 Info" },
      { "Started in", (first_commit_date or "Unknown") },
      { "Lifetime", config_stats.lifetime },
    }

    local stats_grid = voltui.grid_col {
      {
        lines = voltui.table(left_tbl, barlen, "Special"),
        w = barlen,
        pad = 2,
      },
      { lines = voltui.table(right_tbl, barlen, "Special"), w = barlen },
    }
    vim.list_extend(lines, stats_grid)
  end

  -- heatmap
  if ui_state.commit_activity then
    table.insert(lines, { { " ", "" } })
    vim.list_extend(
      lines,
      build_heatmap(ui_state.commit_activity, get_config().size.width)
    )
    lines = add(lines, " ", "")

    local hi_day = config_stats and config_stats.highest_day
    local lo_day = config_stats and config_stats.lowest_day

    if hi_day and lo_day then
      local table_w = get_config().size.width - (state.xpad or 0) * 2

      local streak_start = config_stats.longest_streak_start or "None"
      local streak_end = config_stats.longest_streak_end or "None"

      local h_header = "  Highest"
      local l_header = "  Lowest"
      local s_header = "󰃭  Streak"
      local h_data = tostring(hi_day.count) .. " (" .. hi_day.date .. ")"
      local l_data = tostring(lo_day.count) .. " (" .. lo_day.date .. ")"
      local s_data = streak_start .. " to " .. streak_end

      -- ensure equal width by padding to max length
      local function get_w(s) return api.nvim_strwidth(s) end
      local max_w = math.max(
        get_w(h_header),
        get_w(l_header),
        get_w(s_header),
        get_w(h_data),
        get_w(l_data),
        get_w(s_data)
      )

      local function p(s)
        local diff = max_w - get_w(s)
        local left = math.floor(diff / 2)
        local right = diff - left
        return string.rep(" ", left) .. s .. string.rep(" ", right)
      end

      local extrema_tbl = {
        { p(h_header), p(l_header), p(s_header) },
        { p(h_data), p(l_data), p(s_data) },
      }

      local extrema_table = voltui.table(extrema_tbl, table_w, "WrappedRed0")
      vim.list_extend(lines, extrema_table)
    end
  end
  lines = add(lines, " ", "")

  -- charts & top files
  local width = get_config().size.width - (state.xpad or 0) * 2
  table.insert(lines, { { " ", "" } })

  -- charts row
  local charts_row = {}
  local freq_chart = nil
  local gap = 2
  local left_w = math.floor((width - gap) / 2)
  local right_w = width - left_w - gap

  if size_history and #size_history.values > 0 then
    local size_chart = build_size_chart(size_history, left_w)
    local growth_chart = build_plugin_growth_chart(plugin_history, right_w + 4)
    freq_chart = build_commit_freq_chart(
      config_stats and config_stats.commit_history or {},
      right_w + 4
    )

    charts_row = voltui.grid_col {
      { lines = size_chart, w = left_w, pad = gap },
      { lines = growth_chart, w = right_w },
    }
    vim.list_extend(lines, charts_row)
    lines = add(lines, " ", "")
  end

  -- top 5 largest file types (and freq chart)
  local top_files = build_top_files_table(file_stats, left_w)
  if freq_chart then
    local bottom_row = voltui.grid_col {
      { lines = freq_chart, w = right_w, pad = gap },
      { lines = top_files, w = left_w },
    }
    vim.list_extend(lines, bottom_row)
  else
    vim.list_extend(lines, top_files)
  end

  -- vertical pad
  local ypad = state.ypad or 0
  for _ = 1, ypad do
    table.insert(lines, 1, { { " ", "" } })
  end
  for _ = 1, ypad do
    table.insert(lines, { { " ", "" } })
  end

  return lines
end

-- refreshes heatmap data and redraws
local function refresh_heatmap(buf)
  vim.system(
    { "git", "log", "--format=%ad", "--date=short" },
    { cwd = require("wrapped").config.path, text = true },
    function(out)
      vim.schedule(function()
        local lines = vim.split(out.stdout or "", "\n", { trimempty = true })
        local counts = {}
        for _, d in ipairs(lines) do
          local y, m, day = d:match "(%d+)-(%d+)-(%d+)"
          if y == tostring(state.heatmap_year) then
            local key = day .. m .. y
            counts[key] = (counts[key] or 0) + 1
          end
        end
        ui_state.commit_activity = counts
        volt.redraw(buf, "git_log")
      end)
    end
  )
end

---@param commits string[]
---@param total_count integer|string
---@param plugin_count integer
---@param first_commit_date string
---@param file_stats Wrapped.FileStats
---@param plugin_history Wrapped.PluginHistory
---@param config_stats Wrapped.ConfigStats
---@param commit_activity table<string, integer>
---@param size_history Wrapped.SizeHistory
function M.open(
  commits,
  total_count,
  plugin_count,
  first_commit_date,
  file_stats,
  plugin_history,
  config_stats,
  commit_activity,
  size_history
)
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_set_current_win(ui_state.win)
    return
  end

  -- store for year cycling
  state.first_commit_year =
    tonumber(first_commit_date:match "(%d+)" or os.date "%Y", 10)
  ui_state.commit_activity = commit_activity

  local config = get_config()
  ui_state.buf = api.nvim_create_buf(false, true)
  local w, h = config.size.width, config.size.height
  local row, col =
    math.floor((vim.o.lines - h) / 2) - 1, math.floor((vim.o.columns - w) / 2)

  local border_opts = (type(config.border) == "string" and config.border)
    or (config.border and "single")
    or "none"

  ui_state.win = api.nvim_open_win(ui_state.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = w,
    height = h,
    style = "minimal",
    border = border_opts --[[@as string|string[] ]],
    zindex = 100,
  })

  api.nvim_set_option_value("scrolloff", 0, { win = ui_state.win })

  highlights.apply_float(ui_state.ns)
  api.nvim_win_set_hl_ns(ui_state.win, ui_state.ns)

  volt.gen_data {
    {
      buf = ui_state.buf,
      layout = {
        {
          lines = function()
            return build_content(
              commits,
              total_count,
              plugin_count,
              first_commit_date,
              file_stats,
              plugin_history,
              config_stats,
              size_history
            )
          end,
          name = "git_log",
        },
      },
      xpad = state.xpad,
      ns = ui_state.ns,
    },
  }

  local content_h = require("volt.state")[ui_state.buf].h
  local new_h = math.min(content_h, h, vim.o.lines - 4)

  if new_h ~= h then
    api.nvim_win_set_config(ui_state.win, {
      relative = "editor",
      row = math.max(0, math.floor((vim.o.lines - new_h) / 2) - 1),
      col = col,
      width = w,
      height = new_h,
      border = border_opts --[[@as string|string[] ]],
    })
  end

  volt.run(ui_state.buf, { h = content_h, w = w })

  local buf = ui_state.buf --[[@as integer]]
  local map_opts = { noremap = true, silent = true, callback = close }
  api.nvim_buf_set_keymap(buf, "n", "q", "", map_opts)
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", map_opts)

  -- year cycling keymaps
  local cur_year = tonumber(os.date "%Y", 10)
  local function cycle_year(delta)
    local new_year = state.heatmap_year + delta
    if new_year < state.first_commit_year or new_year > cur_year then return end
    state.heatmap_year = new_year
    refresh_heatmap(buf)
  end

  vim.keymap.set("n", "<", function() cycle_year(-1) end, {
    noremap = true,
    buffer = buf,
    silent = true,
  })
  vim.keymap.set("n", ">", function() cycle_year(1) end, {
    noremap = true,
    buffer = buf,
    silent = true,
  })
end

return M
