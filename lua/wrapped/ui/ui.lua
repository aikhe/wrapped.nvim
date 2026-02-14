local api = vim.api
local volt = require 'volt'
local function get_config()
  return require('wrapped').config
end
local highlights = require 'wrapped.ui.highlights'
local state = require 'wrapped.state'

local M = {}

local ui_state = {
  buf = nil,
  win = nil,
  ns = api.nvim_create_namespace 'WrappedUI',
}

local function pad_vertical(lines)
  local ypad = state.ypad or 0
  if ypad <= 0 then
    return lines
  end

  local res = {}
  for _ = 1, ypad do
    table.insert(res, { { ' ' } })
  end

  vim.list_extend(res, lines)

  for _ = 1, ypad do
    table.insert(res, { { ' ' } })
  end

  return res
end

local function close()
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_win_close(ui_state.win, true)
  end
  if ui_state.buf and api.nvim_buf_is_valid(ui_state.buf) then
    api.nvim_buf_delete(ui_state.buf, { force = true })
  end
  ui_state.win = nil
  ui_state.buf = nil
end

local function create_window()
  local config = get_config()
  ui_state.buf = api.nvim_create_buf(false, true)
  local width = config.size.width
  local height = config.size.height

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = config.border and 'single' or 'none',
    zindex = 100,
  }

  ui_state.win = api.nvim_open_win(ui_state.buf, true, opts)

  -- apply
  highlights.apply_float(ui_state.ns)
  api.nvim_win_set_hl_ns(ui_state.win, ui_state.ns)
end

function M.open(commits)
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_set_current_win(ui_state.win)
    return
  end

  create_window()

  local layout = {
    {
      lines = function()
        local lines = {}
        for _, commit in ipairs(commits) do
          table.insert(lines, { { commit, 'Normal' } })
        end
        return pad_vertical(lines)
      end,
      name = 'git_log',
    },
  }

  volt.gen_data {
    { buf = ui_state.buf, layout = layout, xpad = state.xpad, ns = ui_state.ns },
  }

  volt.run(ui_state.buf, {
    h = get_config().size.height,
    w = get_config().size.width,
  })

  -- Keymaps
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(ui_state.buf, 'n', 'q', '', vim.tbl_extend('force', opts, { callback = close }))
  api.nvim_buf_set_keymap(ui_state.buf, 'n', '<Esc>', '', vim.tbl_extend('force', opts, { callback = close }))
end

return M
