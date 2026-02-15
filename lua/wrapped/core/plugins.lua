---@class Wrapped.Core.Plugins
local M = {}

local function get_path() return require("wrapped").config.path end

---@return integer count
function M.get_count()
  local ok, lazy = pcall(require, "lazy")
  return (ok and lazy) and lazy.stats().count or 0
end

---@return Wrapped.PluginHistory plugin_history
function M.get_history()
  local result = vim
    .system({
      "git",
      "log",
      "-p",
      "--reverse",
      "--format=COMMIT_DATE:%ad",
      "--date=iso",
      "--",
      "lua/plugins",
    }, { cwd = get_path(), text = true })
    :wait()
  if result.code ~= 0 then return { total_ever_installed = 0 } end
  local lines = vim.split(result.stdout, "\n", { trimempty = true })

  ---@type table<string, string>, string|nil, integer
  local seen, cur_date, total_ever = {}, nil, 0

  for _, line in ipairs(lines) do
    if line:match "^COMMIT_DATE:" then
      cur_date = line:match "^COMMIT_DATE:(%d+%-%d+%-%d+)" --[[@as string]]
    elseif line:match "^%+" and not line:match "^%+%+%+" then
      for plugin in line:gmatch "['\"]([%w%-%.%_]+/[%w%-%.%_]+)['\"]" do
        if not seen[plugin] then
          seen[plugin] = cur_date
          total_ever = total_ever + 1
        end
      end
    end
  end

  ---@type string, integer, string, integer
  local oldest, old_date, newest, new_date
  local ok, lazy = pcall(require, "lazy")

  if ok and lazy and lazy.plugins then
    local plugins = lazy.plugins()
    local completed, total = 0, 0 ---@type integer, integer
    local timestamps = {} ---@type table<string, integer>

    for _, plugin in pairs(plugins) do
      if plugin.dir and vim.fn.isdirectory(plugin.dir) == 1 then
        total = total + 1
        vim.system(
          { "git", "log", "-1", "--format=%at" },
          { cwd = plugin.dir, text = true },

          ---@param out vim.SystemCompleted
          function(out)
            if out.code == 0 then
              local ts = tonumber(vim.trim(out.stdout), 10)
              if ts then timestamps[plugin.name] = ts end
            end
            completed = completed + 1
          end
        )
      end
    end

    vim.wait(5000, function() return completed >= total end)

    for name, ts in pairs(timestamps) do
      if not old_date or ts < old_date then
        old_date, oldest = ts, name
      end
      if not new_date or ts > new_date then
        new_date, newest = ts, name
      end
    end
  end

  return { ---@type Wrapped.PluginHistory
    total_ever_installed = total_ever,
    oldest_plugin = oldest and { name = oldest, date = old_date } or nil,
    newest_plugin = newest and { name = newest, date = new_date } or nil,
  }
end

return M
