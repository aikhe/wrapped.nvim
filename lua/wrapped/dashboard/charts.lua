local voltui = require "volt.ui"

---@class Wrapped.UI.Charts
local M = {}

---@param vals integer[]
---@param max_items integer
---@return integer[]
local function downsample(vals, max_items)
  if #vals <= max_items then return vals end
  local out = {}
  local step = (#vals - 1) / (max_items - 1)
  for i = 0, max_items - 1 do
    local idx = math.floor(1 + i * step + 0.5)
    table.insert(out, vals[idx])
  end
  return out
end

---@param size_history Wrapped.SizeHistory
---@param width integer
---@return string[][][] chart
function M.size(size_history, width)
  local vals = size_history.values
  if #vals == 0 then return {} end

  local min_val = math.min(unpack(vals))
  local max_val = math.max(unpack(vals))
  local diff = max_val - min_val

  -- dynamic baseline to zoom in on variation
  local baseline = diff > 0 and math.max(0, math.floor(min_val - diff * 0.5))
    or math.max(0, math.floor(min_val * 0.8))

  if max_val == baseline then max_val = baseline + 1 end
  local range = max_val - baseline

  local scaled = {}
  for _, v in ipairs(vals) do
    table.insert(scaled, math.floor(((v - baseline) / range) * 100))
  end

  local bar_w, bar_gap = 1, 1
  local max_items = math.floor((width - 8) / (bar_w + bar_gap))
  scaled = downsample(scaled, max_items)

  return voltui.graphs.bar {
    val = scaled,
    footer_label = { "󰉋  Config Size Over Time", "WrappedGreen0" },
    format_labels = function(x)
      local val = math.floor(baseline + (x / 100) * range)
      if val >= 1000 then return string.format("%.1fk", val / 1000) end
      return tostring(val)
    end,
    baropts = {
      w = bar_w,
      gap = bar_gap,
      format_hl = function(x)
        if x > 85 then return "WrappedGreen0" end
        if x > 60 then return "WrappedGreen1" end
        if x > 30 then return "WrappedGreen2" end
        return "WrappedGreen3"
      end,
    },
  }
end

---@param plugin_history Wrapped.PluginHistory
---@param width integer
---@return string[][][] chart
function M.plugin_growth(plugin_history, width)
  if not plugin_history then return {} end
  local growth = plugin_history.growth
  if not growth or #growth == 0 then return {} end

  local vals = {}
  for _, entry in ipairs(growth) do
    table.insert(vals, entry.count or 0)
  end

  local min_val = math.min(unpack(vals))
  local max_val = math.max(unpack(vals))
  local diff = max_val - min_val

  local baseline = diff > 5 and math.max(0, math.floor(min_val - diff * 0.3))
    or 0

  if max_val == baseline then max_val = baseline + 1 end
  local range = max_val - baseline

  local scaled = {}
  for _, v in ipairs(vals) do
    local pct = math.floor(((v - baseline) / range) * 100)
    table.insert(scaled, math.min(100, math.max(0, pct)))
  end

  local bar_w, bar_gap = 2, 1
  local max_bars = math.floor((width - 10) / (bar_w + bar_gap))
  if max_bars < 1 then max_bars = 1 end
  scaled = downsample(scaled, max_bars)

  return voltui.graphs.bar {
    val = scaled,
    footer_label = { "󰐱  Plugin Growth Overtime", "WrappedBlue0" },
    format_labels = function(x)
      return tostring(math.floor(baseline + (x / 100) * range))
    end,
    baropts = {
      w = bar_w,
      gap = bar_gap,
      dual_hl = { "WrappedBlue0", "WrappedBlue2" },
    },
  }
end

---@param commit_history integer[]
---@param width integer
---@return string[][][] chart
function M.commit_freq(commit_history, width)
  if not commit_history or #commit_history == 0 then return {} end

  local max_val = math.max(unpack(commit_history))
  if max_val == 0 then max_val = 1 end

  local scaled = {}
  for _, v in ipairs(commit_history) do
    if v <= 0 then
      table.insert(scaled, 0)
    else
      local pct = 20 + math.floor(((v - 1) / math.max(1, max_val - 1)) * 80)
      table.insert(scaled, math.min(100, pct))
    end
  end

  local max_bars = math.floor((width - 10) / 3)
  if max_bars < 1 then max_bars = 1 end
  scaled = downsample(scaled, max_bars)

  local chart = voltui.graphs.dot {
    val = scaled,
    width = width,
    footer_label = { "󰔵  Config Changes Frequency", "WrappedYellow0" },
    format_labels = function(x)
      if x == 10 then return "0" end
      return tostring(1 + math.floor(((x - 20) / 80) * (max_val - 1)))
    end,
    baropts = {
      sidelabels = true,
      icons = { on = " 󰄰", off = " ·" },
      hl = { on = "WrappedYellow0", off = "Comment" },
    },
  }

  -- push chart down to align
  table.insert(chart, 1, { { " ", "" } })
  return chart
end

return M
