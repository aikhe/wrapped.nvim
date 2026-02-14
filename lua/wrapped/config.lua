local M = {}

---@type Wrapped.Config
M.defaults = {
  border = false,
  size = {
    width = 120,
    height = 40,
  },
  exclude_filetype = {
    ".gitmodules",
  },
}

return M
