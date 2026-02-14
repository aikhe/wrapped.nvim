local config = require 'wrapped.config'

local M = {}

M.config = config.defaults

---@class WrappedConfig
---@field enabled boolean

---@param opts WrappedConfig?
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

function M.run()
  if M.config.enabled then
    local commits = require('wrapped.core.git').get_commits()
    require('wrapped.ui.ui').open(commits)
  else
    print 'wrapped.nvim is disabled'
  end
end

return M
