local api = vim.api
local volt = require "volt"
local voltui = require "volt.ui"
local hl = require "wrapped.ui.hl"
local state = require "wrapped.state"
local charts = require "wrapped.dashboard.charts"
local heatmap = require "wrapped.dashboard.heatmap"
local sections = require "wrapped.dashboard.sections"
local plugins_mod = require "wrapped.core.plugins"

---@class Wrapped.Ui
local M = {}

local function close()
  if state.win then pcall(api.nvim_win_close, state.win, true) end
  if state.buf then pcall(api.nvim_buf_delete, state.buf, { force = true }) end
  state.win, state.buf = nil, nil
end

---@param results Wrapped.Results
---@return string[][][] lines
local function build_content(results)
  local git = results.git or {}
  local files = results.files
  local plugin_history = results.plugins
  local config_stats = git.config_stats
  local size_history = git.size_history

  local cfg = state.config
  local width = cfg.size.width - state.xpad * 2
  local gap = 2
  local left_w = math.floor((width - gap) / 2)
  local right_w = width - left_w - gap

  local lines = {}

  -- progress bars
  vim.list_extend(
    lines,
    sections.stats_bars(
      git.total_count,
      plugins_mod.get_count(),
      plugin_history and plugin_history.total_ever_installed or 0,
      files.total_lines
    )
  )
  table.insert(lines, { { " ", "" } })
  table.insert(lines, { { " ", "" } })

  -- plugin & file info tables
  vim.list_extend(lines, sections.plugins_files(plugin_history, files))

  -- sessions & history tables
  if config_stats then
    local barlen = math.floor((width - 2) / 2)
    local left_tbl = {
      { "  Sessions", "  Time" },
      { "Streak", (config_stats.longest_streak or 0) .. " days" },
      { "Last Change", config_stats.last_change or "Unknown" },
    }
    local right_tbl = {
      { "  History", "󰌵 Info" },
      { "Started in", git.first_commit_date or "Unknown" },
      { "Lifetime", config_stats.lifetime or "Unknown" },
    }
    vim.list_extend(
      lines,
      voltui.grid_col {
        {
          lines = voltui.table(left_tbl, barlen, "Special"),
          w = barlen,
          pad = 2,
        },
        { lines = voltui.table(right_tbl, barlen, "Special"), w = barlen },
      }
    )
  end

  -- heatmap
  if state.commit_activity then
    table.insert(lines, { { " ", "" } })
    vim.list_extend(lines, heatmap.build(state.commit_activity, cfg.size.width))
    table.insert(lines, { { " ", "" } })

    if config_stats then
      local table_w = cfg.size.width - state.xpad * 2
      local streak = sections.streak_table(config_stats, table_w)
      if #streak > 0 then vim.list_extend(lines, streak) end
    end
  end
  table.insert(lines, { { " ", "" } })
  table.insert(lines, { { " ", "" } })

  -- charts row (size + plugin growth)
  if size_history and #size_history.values > 0 then
    local size_chart = charts.size(size_history, left_w)
    local growth_chart = charts.plugin_growth(plugin_history, right_w + 4)

    vim.list_extend(
      lines,
      voltui.grid_col {
        { lines = size_chart, w = left_w, pad = gap },
        { lines = growth_chart, w = right_w },
      }
    )
    table.insert(lines, { { " ", "" } })
  end

  -- bottom row (freq chart + top files)
  local freq_chart = charts.commit_freq(
    config_stats and config_stats.commit_history or {},
    right_w + 4
  )
  local top_files = sections.top_files(files, left_w)

  if #freq_chart > 0 then
    vim.list_extend(
      lines,
      voltui.grid_col {
        { lines = freq_chart, w = right_w, pad = gap },
        { lines = top_files, w = left_w },
      }
    )
  else
    vim.list_extend(lines, top_files)
  end

  -- vertical padding
  for _ = 1, state.ypad do
    table.insert(lines, 1, { { " ", "" } })
    table.insert(lines, { { " ", "" } })
  end

  return lines
end

---@param results Wrapped.Results
M.open = function(results)
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    return
  end

  local git = results.git or {}
  local cfg = state.config

  -- store for year cycling
  state.first_commit_year =
    tonumber((git.first_commit_date or ""):match "(%d+)" or os.date "%Y", 10)
  state.commit_activity = git.commit_activity

  local buf = api.nvim_create_buf(false, true)
  if not buf or buf == 0 then return end
  state.buf = buf

  local w, h = cfg.size.width, cfg.size.height
  local row = math.floor((vim.o.lines - h) / 2) - 1
  local col = math.floor((vim.o.columns - w) / 2)

  local border_opts = (type(cfg.border) == "string" and cfg.border)
    or (cfg.border and "single")
    or "none"

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = w,
    height = h,
    style = "minimal",
    border = border_opts,
    zindex = 100,
  })
  if not win or win == 0 then return end
  state.win = win

  api.nvim_set_option_value("scrolloff", 0, { win = win })
  hl.apply_float(state.ns)
  api.nvim_win_set_hl_ns(win, state.ns)

  volt.gen_data {
    {
      buf = buf,
      layout = {
        {
          lines = function() return build_content(results) end,
          name = "git_log",
        },
      },
      xpad = state.xpad,
      ns = state.ns,
    },
  }

  -- auto-fit height to content
  local content_h = require("volt.state")[buf].h
  local new_h = math.min(content_h, h, vim.o.lines - 4)

  if new_h ~= h then
    api.nvim_win_set_config(win, {
      relative = "editor",
      row = math.max(0, math.floor((vim.o.lines - new_h) / 2) - 1),
      col = col,
      width = w,
      height = new_h,
      border = border_opts,
    })
  end

  volt.run(buf, { h = content_h, w = w })

  -- keymaps
  local map_opts = { noremap = true, silent = true, callback = close }
  api.nvim_buf_set_keymap(buf, "n", "q", "", map_opts)
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", map_opts)

  -- year cycling
  local cur_year = tonumber(os.date "%Y", 10)
  local function cycle_year(delta)
    local new_year = state.heatmap_year + delta
    if new_year < state.first_commit_year or new_year > cur_year then return end
    state.heatmap_year = new_year
    heatmap.refresh(buf)
  end

  vim.keymap.set(
    "n",
    "<",
    function() cycle_year(-1) end,
    { buffer = buf, silent = true }
  )
  vim.keymap.set(
    "n",
    ">",
    function() cycle_year(1) end,
    { buffer = buf, silent = true }
  )
end

return M
