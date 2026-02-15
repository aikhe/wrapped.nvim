require "volt.highlights"
local api = vim.api
local get_hl = require("volt.utils").get_hl
local lighten = require("volt.color").change_hex_lightness
local mix = require("volt.color").mix

---@class Wrapped.UI.Highlights
local M = {}

---@return string bg
local function get_bg()
  if vim.g.base46_cache then
    return dofile(vim.g.base46_cache .. "colors").black
  end
  return get_hl("NormalFloat").bg
end

-- 4 base colors cycling across months
M.month_colors = { "Red", "Green", "Blue", "Yellow" }

---@param ns integer
function M.apply_float(ns)
  local config = require("wrapped").config
  local bg = get_bg()
  local win_bg = config.border and bg or lighten(bg, 2) ---@type string
  local text_light = get_hl("NormalFloat").fg ---@type string
  local border_bg = config.border and "NONE" or win_bg ---@type string
  local border_fg = config.border and lighten(bg, 15) or win_bg ---@type string
  local title_fg = get_hl("ExBlue").fg
  local comment_fg = get_hl("Comment").fg

  local hl = { ---@type table<string, vim.api.keyset.highlight>
    Normal = { bg = win_bg, fg = text_light },
    FloatBorder = { fg = border_fg, bg = border_bg },
    WrappedTitle = { fg = title_fg, bold = true },
    WrappedKey = { fg = text_light, bg = lighten(bg, 10) },
    WrappedLabel = { fg = lighten(comment_fg, 20) },
    WrappedSeparator = { fg = mix(comment_fg, win_bg, 60) },
  }
  for group, opts in pairs(hl) do
    api.nvim_set_hl(ns, group, opts)
  end

  -- per-color intensity levels (0=brightest, 3=dimmest)
  local color_sources = { ---@type table<string, string>
    Red = get_hl("ExRed").fg,
    Green = get_hl("ExGreen").fg,
    Blue = get_hl("ExBlue").fg,
    Yellow = get_hl("ExYellow").fg,
  }
  local mix_levels = { 10, 40, 60, 80 }
  for name, fg in pairs(color_sources) do
    for i, pct in ipairs(mix_levels) do
      api.nvim_set_hl(
        ns,
        ("Wrapped%s%s"):format(name, i - 1),
        { fg = mix(fg, win_bg, pct) }
      )
    end
  end
end

return M
