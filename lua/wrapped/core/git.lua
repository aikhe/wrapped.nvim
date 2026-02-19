---@class Wrapped.Core.Git
local M = {}

---@return string path
local function get_path() return require("wrapped").config.path end

---@param args string[]
---@param cb fun(stdout: string)
local function exec_git(args, cb)
  vim.system(
    { "git", unpack(args) },
    { cwd = get_path(), text = true },
    function(out)
      vim.schedule(function() cb(out.stdout or "") end)
    end
  )
end

---@param list string[]
---@param n integer
---@return string[]
function M._pick_random(list, n)
  if #list <= n then return list end
  local result, indices = {}, {}
  while #indices < n do
    local idx = math.random(1, #list)
    if not vim.list_contains(indices, idx) then
      table.insert(indices, idx)
      table.insert(result, list[idx])
    end
  end
  return result
end

-- seconds to human-readable
---@param secs integer
---@return string ago
function M._format_ago(secs)
  local days = math.floor(secs / 86400)
  if days >= 365 then return ("%.1f years ago"):format(days / 365) end
  if days >= 30 then return math.floor(days / 30) .. " months ago" end
  if days >= 1 then return days .. " days ago" end
  if secs >= 3600 then return math.floor(secs / 3600) .. " hours ago" end
  return math.floor(secs / 60) .. " minutes ago"
end

-- longest consecutive day streak from sorted date strings
---@param sorted string[]
---@return integer streak, string|nil start_date, string|nil end_date
function M._parse_streak(sorted)
  if #sorted == 0 then return 0, nil, nil end
  local max_streak, cur_streak = 1, 1
  local cur_start = sorted[1]
  local max_start, max_end = sorted[1], sorted[1]

  for i = 2, #sorted do
    local y, m, d = sorted[i]:match "(%d+)-(%d+)-(%d+)"
    local py, pm, pd = sorted[i - 1]:match "(%d+)-(%d+)-(%d+)"
    local t1 = os.time {
      year = tonumber(y, 10),
      month = tonumber(m, 10),
      day = tonumber(d, 10),
    }
    local t0 = os.time {
      year = tonumber(py, 10),
      month = tonumber(pm, 10),
      day = tonumber(pd, 10),
    }
    if math.abs(t1 - t0) <= 86400 then
      cur_streak = cur_streak + 1
      if cur_streak > max_streak then
        max_streak = cur_streak
        max_start = cur_start
        max_end = sorted[i]
      end
    else
      cur_streak = 1
      cur_start = sorted[i]
    end
  end
  return max_streak, max_start, max_end
end

---@param date_str string
---@return string lifetime
function M._parse_lifetime(date_str)
  local y, m, d = date_str:match "(%d+)-(%d+)-(%d+)"
  if not (y and m and d) then return "Unknown" end
  local age_days = (
    os.time()
    - os.time {
      year = tonumber(y, 10),
      month = tonumber(m, 10),
      day = tonumber(d, 10),
    }
  ) / 86400
  if age_days >= 365 then return ("%.1f years old"):format(age_days / 365) end
  if age_days >= 30 then return math.floor(age_days / 30) .. " months old" end
  return math.floor(age_days) .. " days old"
end

---@param date_str string
---@return string last_change
function M._parse_last_change(date_str)
  local y, m, d = date_str:match "(%d+)-(%d+)-(%d+)"
  if not (y and m and d) then return "Unknown" end
  return M._format_ago(os.time() - os.time {
    year = tonumber(y, 10),
    month = tonumber(m, 10),
    day = tonumber(d, 10),
  })
end

---@param dates string[]
---@return string[] sorted
function M._unique_sorted(dates)
  local seen = {} ---@type table<string, boolean>
  for _, d in ipairs(dates) do
    seen[d] = true
  end
  local sorted = {} ---@type string[]
  for d in pairs(seen) do
    table.insert(sorted, d)
  end
  table.sort(sorted)
  return sorted
end

---@param subjects string[]
---@return string shortest, string longest
function M._find_extremes(subjects)
  local shortest, longest = subjects[1] or "", subjects[1] or ""
  for _, s in ipairs(subjects) do
    if s:len() < shortest:len() and s:len() > 0 then shortest = s end
    if s:len() > longest:len() then longest = s end
  end
  return shortest, longest
end

---@param year integer
---@param cb fun(data: Wrapped.GitStats)
function M.get_all_data_async(year, cb)
  local data = {} ---@type Wrapped.GitStats
  local total = 6
  local count = 0

  local function check()
    count = count + 1
    if count == total then cb(data) end
  end

  -- random commits
  exec_git({ "log", "--format=%s" }, function(out)
    data.commits = M._pick_random(vim.split(out, "\n", { trimempty = true }), 5)
    check()
  end)

  -- total commit count
  exec_git({ "rev-list", "--count", "HEAD" }, function(out)
    data.total_count = vim.trim(out)
    check()
  end)

  -- first commit date
  exec_git({ "log", "--reverse", "--format=%ad", "--date=short" }, function(out)
    local lines = vim.split(out, "\n", { trimempty = true })
    data.first_commit_date = lines[1] or "Unknown"
    check()
  end)

  -- config stats (streak, lifetime, commit messages)
  exec_git({ "log", "--format=%ad|%s", "--date=short" }, function(out)
    local lines = vim.split(out, "\n", { trimempty = true })
    local dates, subjects = {}, {}
    local date_counts = {}
    local monthly_counts = {}
    for _, l in ipairs(lines) do
      local d, s = l:match "([^|]+)|(.*)"
      if d and s then
        table.insert(dates, d)
        table.insert(subjects, s)
        date_counts[d] = (date_counts[d] or 0) + 1
        local ym = d:sub(1, 7)
        monthly_counts[ym] = (monthly_counts[ym] or 0) + 1
      end
    end

    local sorted_months = {}
    for ym in pairs(monthly_counts) do
      table.insert(sorted_months, ym)
    end
    table.sort(sorted_months)

    local commit_history = {}
    for _, ym in ipairs(sorted_months) do
      table.insert(commit_history, monthly_counts[ym])
    end

    local sorted = M._unique_sorted(dates)
    local shortest, longest = M._find_extremes(subjects)
    local streak, streak_start, streak_end = M._parse_streak(sorted)

    local highest_day = { count = 0, date = "None" }
    local lowest_day = { count = math.huge, date = "None" }

    for d, c in pairs(date_counts) do
      if c > highest_day.count then highest_day = { count = c, date = d } end
      if c < lowest_day.count then lowest_day = { count = c, date = d } end
    end
    if lowest_day.count == math.huge then
      lowest_day = { count = 0, date = "None" }
    end

    data.config_stats = {
      longest_streak = streak,
      longest_streak_start = streak_start,
      longest_streak_end = streak_end,
      highest_day = highest_day,
      lowest_day = lowest_day,
      commit_history = commit_history,
      last_change = dates[1] and M._parse_last_change(dates[1]) or "Unknown",
      lifetime = sorted[1] and M._parse_lifetime(sorted[1]) or "Unknown",
      shortest_msg = shortest,
      longest_msg = longest,
    }
    check()
  end)

  -- commit activity for heatmap
  exec_git({ "log", "--format=%ad", "--date=short" }, function(out)
    local lines = vim.split(out, "\n", { trimempty = true })
    local counts = {}
    for _, d in ipairs(lines) do
      local y, m, day = d:match "(%d+)-(%d+)-(%d+)"
      if y == tostring(year) then
        local key = day .. m .. y
        counts[key] = (counts[key] or 0) + 1
      end
    end
    data.commit_activity = counts
    check()
  end)

  -- size history
  exec_git(
    { "log", "--reverse", "--format=%H %ad", "--date=short" },
    function(out)
      local log_lines = vim.split(out, "\n", { trimempty = true })
      if #log_lines == 0 then
        data.size_history = { values = {}, labels = {} }
        check()
        return
      end

      vim.system(
        { "git", "hash-object", "-t", "tree", "/dev/null" },
        { cwd = get_path(), text = true },
        function(obj_out)
          local empty_tree = (obj_out.stdout or ""):match "%S+"
          local samples = {}
          local step = math.max(1, math.floor(#log_lines / 49))
          for i = 1, #log_lines, step do
            table.insert(samples, log_lines[i])
          end
          if samples[#samples] ~= log_lines[#log_lines] then
            table.insert(samples, log_lines[#log_lines])
          end

          local values, labels = {}, {}

          -- sequential chain to avoid blocking event loop
          local function process_next(i)
            if i > #samples then
              vim.schedule(function()
                data.size_history = { values = values, labels = labels }
                check()
              end)
              return
            end

            local hash, date = samples[i]:match "(%S+)%s+(%S+)"
            if hash and empty_tree then
              vim.system(
                { "git", "diff", "--shortstat", empty_tree, hash },
                { cwd = get_path(), text = true },
                function(diff_out)
                  local ins = (diff_out.stdout or ""):match "(%d+) insertion"
                  table.insert(values, ins and tonumber(ins, 10) or 0)
                  table.insert(labels, date)
                  process_next(i + 1)
                end
              )
            else
              process_next(i + 1)
            end
          end

          process_next(1)
        end
      )
    end
  )
end

return M
