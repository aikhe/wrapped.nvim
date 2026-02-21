---@class Wrapped.Core.Plugins
local M = {}

---@return string path
local function get_path() return require("wrapped.state").config.path end
---@return integer count
function M.get_count()
  local ok, lazy = pcall(require, "lazy")
  return (ok and lazy) and lazy.stats().count or 0
end

---@param cb fun(history: Wrapped.PluginHistory)
function M.get_history_async(cb)
  vim.system({
    "git",
    "log",
    "-p",
    "--reverse",
    "--format=COMMIT_DATE:%ad",
    "--date=iso",
    "--",
    ":**/*.lua",
  }, { cwd = get_path(), text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function() cb { total_ever_installed = 0 } end)
      return
    end

    local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
    local seen, cur_date, total_ever = {}, nil, 0
    local growth = {}

    for _, line in ipairs(lines) do
      if line:match "^COMMIT_DATE:" then
        cur_date = line:match "^COMMIT_DATE:(%d+%-%d+%-%d+)"
      elseif line:match "^%+" and not line:match "^%+%+%+" then
        for plugin in line:gmatch "['\"]([%w%-%.%_]+/[%w%-%.%_]+)['\"]" do
          if not seen[plugin] then
            seen[plugin] = cur_date
            total_ever = total_ever + 1
            table.insert(growth, { date = cur_date, count = total_ever })
          end
        end
      end
    end

    local ok, lazy = pcall(require, "lazy")
    if not (ok and lazy and lazy.plugins) then
      vim.schedule(
        function() cb { total_ever_installed = total_ever, growth = growth } end
      )
      return
    end

    local plugins = lazy.plugins()
    local total = 0
    local target_plugins = {}

    for _, p in pairs(plugins) do
      if p.dir and vim.fn.isdirectory(p.dir) == 1 then
        total = total + 1
        table.insert(target_plugins, p)
      end
    end

    if total == 0 then
      vim.schedule(function() cb { total_ever_installed = total_ever } end)
      return
    end

    -- one at a time to avoid blocking the event loop
    local timestamps = {}
    local function process_next(i)
      if i > total then
        vim.schedule(function()
          local oldest, old_date, newest, new_date
          for name, ts in pairs(timestamps) do
            if not old_date or ts < old_date then
              old_date, oldest = ts, name
            end
            if not new_date or ts > new_date then
              new_date, newest = ts, name
            end
          end
          cb {
            total_ever_installed = total_ever,
            growth = growth,
            oldest_plugin = oldest and { name = oldest, date = old_date }
              or nil,
            newest_plugin = newest and { name = newest, date = new_date }
              or nil,
          }
        end)
        return
      end

      local p = target_plugins[i]
      vim.system(
        { "git", "log", "-1", "--format=%at" },
        { cwd = p.dir, text = true },
        function(out)
          if out.code == 0 then
            local ts = tonumber(vim.trim(out.stdout or ""), 10)
            if ts then timestamps[p.name] = ts end
          end
          process_next(i + 1)
        end
      )
    end

    process_next(1)
  end)
end

return M
