local Job = require 'plenary.job'

local M = {}

---@return string[]
function M.get_commits()
  local job = Job:new {
    command = 'git',
    args = { 'log', '-n', '5', '--oneline' },
    cwd = vim.fn.getcwd(),
  }

  job:sync()
  return job:result()
end

return M
