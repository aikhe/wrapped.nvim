local api = vim.api
require 'volt.highlights'
local get_hl = require('volt.utils').get_hl
local lighten = require('volt.color').change_hex_lightness
local config = require('wrapped.init').config

local M = {}

local function get_bg()
  if vim.g.base46_cache then
    return dofile(vim.g.base46_cache .. 'colors').black
  end
  return get_hl('Normal').bg
end

function M.apply_float(ns)
  local bg = get_bg()
  local win_bg = config.border and bg or lighten(bg, 2)
  local text_light = get_hl('Normal').fg

  local border_bg = config.border and 'NONE' or win_bg
  local term_border_fg = config.border and lighten(bg, 15) or win_bg

  api.nvim_set_hl(ns, 'Normal', { bg = win_bg, fg = text_light })
  api.nvim_set_hl(ns, 'FloatBorder', { fg = term_border_fg, bg = border_bg })
  api.nvim_set_hl(ns, 'WrappedTitle', { fg = text_light, bold = true })
  api.nvim_set_hl(ns, 'WrappedKey', { fg = text_light, bg = lighten(bg, 10) })
  api.nvim_set_hl(ns, 'WrappedLabel', { fg = get_hl('Comment').fg })
end

return M
