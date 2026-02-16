local api = vim.api
local highlights = require "wrapped.ui.highlights"
local state_config = require "wrapped.state"

---@class Wrapped.Loading
local M = {}

local state = { ---@type Wrapped.LoadingState
  buf = nil,
  win = nil,
  timer = nil,
  index = 1,
  ns = api.nvim_create_namespace "WrappedLoading",
}

local frames =
  { "⢎ ", "⠎⠁", "⠊⠑", "⠈⠱", " ⡱", "⢀⡰", "⢄⡠", "⢆⡀" }

function M.open()
  if state.win and api.nvim_win_is_valid(state.win) then return end

  local config = require("wrapped").config
  state.buf = api.nvim_create_buf(false, true)

  local text = "Loading Wrapped"
  local xpad = state_config.xpad or 2
  local ypad = state_config.ypad or 1

  local width = #text + 4 + (xpad * 2)
  local height = 1 + (ypad * 2)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)

  local border_opts = (type(config.border) == "string" and config.border)
    or (config.border and "single")
    or "none"

  state.win = api.nvim_open_win(state.buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = border_opts,
    zindex = 200,
  })

  highlights.apply_float(state.ns)
  api.nvim_win_set_hl_ns(state.win, state.ns)

  local function update_text()
    if not state.buf or not api.nvim_buf_is_valid(state.buf) then return end

    local frame = frames[state.index]
    local pad_str = string.rep(" ", xpad)
    local line_text = pad_str .. text .. " " .. frame .. pad_str

    if #line_text < width then
      line_text = line_text .. string.rep(" ", width - #line_text)
    end

    local lines = {}
    for _ = 1, ypad do
      table.insert(lines, string.rep(" ", width))
    end
    table.insert(lines, line_text)
    for _ = 1, ypad do
      table.insert(lines, string.rep(" ", width))
    end

    api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)

    -- hl
    api.nvim_buf_set_extmark(state.buf, state.ns, ypad, xpad, {
      end_col = xpad + #text,
      hl_group = "WrappedGreen0",
    })
    api.nvim_buf_set_extmark(state.buf, state.ns, ypad, xpad + #text + 1, {
      end_col = xpad + #text + 1 + #frame,
      hl_group = "WrappedGreen0",
    })
  end

  state.timer = vim.uv.new_timer()
  state.timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      state.index = (state.index % #frames) + 1
      update_text()
    end)
  )
end

function M.close()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
  if state.buf and api.nvim_buf_is_valid(state.buf) then
    api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win, state.buf = nil, nil
  state.index = 1
end

return M
