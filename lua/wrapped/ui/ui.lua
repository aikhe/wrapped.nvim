local api = vim.api
local volt = require "volt"
local voltui = require "volt.ui"
local highlights = require "wrapped.ui.highlights"
local state = require "wrapped.state"

local M = {}
local ui_state =
  { buf = nil, win = nil, ns = api.nvim_create_namespace "WrappedUI" }

local function get_config() return require("wrapped").config end

local function close()
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_win_close(ui_state.win, true)
  end
  if ui_state.buf and api.nvim_buf_is_valid(ui_state.buf) then
    api.nvim_buf_delete(ui_state.buf, { force = true })
  end
  ui_state.win, ui_state.buf = nil, nil
end

local function build_content(
  commits,
  total_count,
  plugin_count,
  first_commit_date,
  file_stats,
  plugin_history
)
  local lines = {}
  local function add(text, hl)
    table.insert(lines, { { text, hl or "Special" } })
  end

  add("Total Commits: " .. total_count)
  add("Total Plugins: " .. (plugin_count or 0))
  add(
    "Total Plugins Ever: "
      .. (plugin_history and plugin_history.total_ever_installed or "Unknown")
  )

  if plugin_history then
    if plugin_history.oldest_plugin then
      add(
        "Oldest Unupdated Plugin: "
          .. plugin_history.oldest_plugin.name
          .. " ("
          .. os.date("%Y-%m-%d", plugin_history.oldest_plugin.date)
          .. ")"
      )
    end
    if plugin_history.newest_plugin then
      add(
        "Newly Updated Plugin: "
          .. plugin_history.newest_plugin.name
          .. " ("
          .. os.date("%Y-%m-%d", plugin_history.newest_plugin.date)
          .. ")"
      )
    end
  end

  add("Started in: " .. (first_commit_date or "Unknown"))
  add("Total Lines: " .. file_stats.total_lines)
  add(
    "Biggest File: "
      .. file_stats.biggest.name
      .. " ("
      .. file_stats.biggest.lines
      .. ")"
  )
  add(
    "Smallest File: "
      .. file_stats.smallest.name
      .. " ("
      .. file_stats.smallest.lines
      .. ")"
  )
  add(string.rep("─", 20), "Comment")

  for _, commit in ipairs(commits) do
    table.insert(lines, { { commit, "Normal" } })
  end
  table.insert(lines, { { " ", "" } })

  local tbl_data = { { "Name", "Lines" } }
  for _, stat in ipairs(file_stats.lines_by_type) do
    table.insert(tbl_data, { stat.name, tostring(stat.lines) })
  end

  local table_lines = voltui.table(
    tbl_data,
    get_config().size.width - (state.xpad or 0) * 2,
    "Special"
  )
  vim.list_extend(lines, table_lines)

  -- vertical padding
  local ypad = state.ypad or 0
  for _ = 1, ypad do
    table.insert(lines, 1, { { " ", "" } })
  end
  for _ = 1, ypad do
    table.insert(lines, { { " ", "" } })
  end

  return lines
end

---@param commits string[]
---@param total_count number|string
---@param plugin_count number
---@param first_commit_date string
---@param file_stats Wrapped.FileStats
---@param plugin_history Wrapped.PluginHistory
function M.open(
  commits,
  total_count,
  plugin_count,
  first_commit_date,
  file_stats,
  plugin_history
)
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_set_current_win(ui_state.win)
    return
  end

  local config = get_config()
  ui_state.buf = api.nvim_create_buf(false, true)
  local w, h = config.size.width, config.size.height
  local row, col =
    math.floor((vim.o.lines - h) / 2), math.floor((vim.o.columns - w) / 2)

  ui_state.win = api.nvim_open_win(ui_state.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = w,
    height = h,
    style = "minimal",
    border = config.border and "single" or "none",
    zindex = 100,
  })

  highlights.apply_float(ui_state.ns)
  api.nvim_win_set_hl_ns(ui_state.win, ui_state.ns)

  local content = build_content(
    commits,
    total_count,
    plugin_count,
    first_commit_date,
    file_stats,
    plugin_history
  )
  volt.gen_data {
    {
      buf = ui_state.buf,
      layout = { { lines = function() return content end, name = "git_log" } },
      xpad = state.xpad,
      ns = ui_state.ns,
    },
  }

  local content_h = require("volt.state")[ui_state.buf].h
  local new_h = math.min(content_h, h, vim.o.lines - 4)

  if new_h ~= h then
    api.nvim_win_set_config(ui_state.win, {
      relative = "editor",
      row = math.max(0, math.floor((vim.o.lines - new_h) / 2)),
      col = col,
      width = w,
      height = new_h,
    })
  end

  volt.run(ui_state.buf, { h = content_h, w = w })

  local map_opts = { noremap = true, silent = true, callback = close }
  api.nvim_buf_set_keymap(ui_state.buf, "n", "q", "", map_opts)
  api.nvim_buf_set_keymap(ui_state.buf, "n", "<Esc>", "", map_opts)
end

return M
