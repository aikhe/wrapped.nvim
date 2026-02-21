local api = vim.api
local highlights = require "wrapped.ui.hl"

local M = {}
local state = {
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

  local wstate = require "wrapped.state"
  local config = wstate.config
  state.buf = api.nvim_create_buf(false, true)

  local text = "Loading Wrapped"
  local x, y = wstate.xpad, wstate.ypad
  local w, h = #text + 4 + (x * 2) - 1, 1 + (y * 2)
  local border_opts = (type(config.border) == "string" and config.border)
    or (config.border and "single")
    or "none"

  state.win = api.nvim_open_win(state.buf, false, {
    relative = "editor",
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2) - 1,
    col = math.floor((vim.o.columns - w) / 2),
    style = "minimal",
    border = border_opts,
    zindex = 200,
  })

  highlights.apply_float(state.ns)
  api.nvim_win_set_hl_ns(state.win, state.ns)

  local pad, blank = string.rep(" ", x), string.rep(" ", w)
  local lines = {}
  for _ = 1, y do
    table.insert(lines, blank)
  end
  table.insert(lines, "")
  for _ = 1, y do
    table.insert(lines, blank)
  end
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)

  state.timer = vim.uv.new_timer()
  state.timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      if not state.buf or not api.nvim_buf_is_valid(state.buf) then return end
      state.index = (state.index % #frames) + 1
      local frame = frames[state.index]
      api.nvim_buf_set_lines(
        state.buf,
        y,
        y + 1,
        false,
        { pad .. text .. " " .. frame .. pad }
      )
      api.nvim_buf_set_extmark(state.buf, state.ns, y, x, {
        id = 1,
        end_col = x + #text + #frame,
        hl_group = "WrappedGreen0",
      })
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
