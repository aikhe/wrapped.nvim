local voltui = require "volt.ui"
local highlights = require "wrapped.ui.hl"
local state = require "wrapped.state"

---@class Wrapped.UI.Heatmap
local M = {}

local month_colors = highlights.month_colors

-- zero-padded two digits
---@param n integer
---@return string
local function dd(n) return n < 10 and "0" .. n or tostring(n) end

-- returns intensity 0 (brightest) to 3 (dimmest)
---@param n integer
---@return string
local function get_intensity(n)
  if n > 5 then return "0" end
  if n > 2 then return "1" end
  if n > 0 then return "2" end
  return "3"
end

---@param y integer
---@return boolean
local function is_leap(y) return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0) end

---@param activity table<string, integer>
---@param width integer
---@return string[][][] heatmap
function M.build(activity, width)
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

  -- month header row with cycling color
  local header = { { " »", "Comment" }, { "  " } }
  for i = 1, 12 do
    local color = month_colors[((i - 1) % #month_colors) + 1]
    table.insert(header, { "  " .. months[i] .. "  ", "Ex" .. color })
    if i < 12 then table.insert(header, { "  " }) end
  end

  local xpad = state.xpad or 0
  local sep = voltui.separator("─", width - xpad * 2 - 4, "Comment")
  local lines = { header, sep }

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

    local color = month_colors[((m - 1) % #month_colors) + 1]
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

  -- legend row
  local legend = {
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
  table.insert(lines, 1, voltui.hpad(legend, width - xpad * 2 - 4))

  return lines
end

-- re-fetch commit activity for a different year and redraw
---@param buf integer
function M.refresh(buf)
  vim.system(
    { "git", "log", "--format=%ad", "--date=short" },
    { cwd = state.config.path, text = true },
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
        state.commit_activity = counts
        require("volt").redraw(buf, "git_log")
      end)
    end
  )
end

return M
