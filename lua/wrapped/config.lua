---@class Wrapped.Config
local M = {}

---@return WrappedConfig defaults
function M.defaults()
  return { ---@type WrappedConfig
    path = vim.fn.stdpath "config",
    border = false,
    size = {
      width = 120,
      height = 40,
    },
    exclude_filetype = {
      ".gitmodules",
    },
    cap = {
      commits = 1000,
      plugins = 100,
      plugins_ever = 200,
      lines = 10000,
    },
  }
end

return M
