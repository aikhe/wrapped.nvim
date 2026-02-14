local Job = require "plenary.job"
local M = {}
local config_path = vim.fn.stdpath "config"

local function exec_git(args)
  local job = Job:new {
    command = "git",
    args = args,
    cwd = config_path,
  }
  job:sync()
  return job:result()
end

---@return string[]
function M.get_commits() return exec_git { "log", "-n", "5", "--oneline" } end

---@return string
function M.get_total_count()
  return exec_git({ "rev-list", "--count", "HEAD" })[1] or "0"
end

---@return string
function M.get_first_commit_date()
  return exec_git({ "log", "--reverse", "--format=%ad", "--date=short" })[1]
    or "Unknown"
end

return M
