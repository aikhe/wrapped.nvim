---@class Wrapped.Core.Files
local M = {}

---@return string path
local function get_path() return require("wrapped.state").config.path end

---@param file string
---@return string ext
function M._get_ext(file) return (file:match "%.([^%.]+)$" or "no ext"):lower() end

---@param stats Wrapped.FileStats
---@param excluded table<string, boolean>
---@param file string
---@param count integer
function M._process_file(stats, excluded, file, count)
  local ext = M._get_ext(file)
  if excluded[ext] then return end

  stats.total_lines = stats.total_lines + count
  if count > stats.biggest.lines then
    stats.biggest = { name = file, lines = count }
  end
  if count > 0 and count < stats.smallest.lines then
    stats.smallest = { name = file, lines = count }
  end
  stats.lines_by_type[ext] = (stats.lines_by_type[ext] or 0) + count
  table.insert(stats.top_files, { name = file, lines = count })
end

---@param cb fun(stats: Wrapped.FileStats)
function M.get_stats_async(cb)
  local config_path = get_path()

  -- get empty tree hash first, then diff against HEAD for per-file line counts
  vim.system(
    { "git", "hash-object", "-t", "tree", "/dev/null" },
    { cwd = config_path, text = true },
    function(hash_out)
      local empty_tree = vim.trim(hash_out.stdout or "")
      if empty_tree == "" then
        vim.schedule(
          function()
            cb {
              total_lines = 0,
              biggest = { name = "None", lines = 0 },
              smallest = { name = "None", lines = 0 },
              lines_by_type = {},
              top_files = {},
            }
          end
        )
        return
      end

      -- git diff --numstat outputs: <added> <removed> <file> per line
      -- against empty tree, added = total lines in file
      -- we omit HEAD to include staged and modified tracked files
      vim.system(
        { "git", "diff", "--numstat", empty_tree },
        { cwd = config_path, text = true },
        function(diff_out)
          -- also get untracked files
          vim.system(
            { "git", "ls-files", "--others", "--exclude-standard" },
            { cwd = config_path, text = true },
            function(ls_out)
              vim.schedule(function()
                local stats = { ---@type Wrapped.FileStats
                  total_lines = 0,
                  biggest = { name = "", lines = 0 },
                  smallest = { name = "", lines = math.huge },
                  lines_by_type = {},
                  top_files = {},
                }

                local excluded_config = require("wrapped.state").config.exclude_filetype
                  or {}
                local excluded = {}
                for _, ext in ipairs(excluded_config) do
                  excluded[ext] = true
                end

                -- parse tracked/modified
                local diff_lines =
                  vim.split(diff_out.stdout or "", "\n", { trimempty = true })
                for _, line in ipairs(diff_lines) do
                  local added, _, file = line:match "^(%d+)%s+(%d+)%s+(.+)$"
                  if added and file then
                    M._process_file(
                      stats,
                      excluded,
                      file,
                      tonumber(added, 10) or 0
                    )
                  end
                end

                -- parse untracked
                local untracked_files =
                  vim.split(ls_out.stdout or "", "\n", { trimempty = true })
                for _, file in ipairs(untracked_files) do
                  local full_path = config_path .. "/" .. file
                  local f = io.open(full_path, "r")

                  if f then
                    local content = f:read "*a" or ""
                    f:close()
                    local _, count = content:gsub("\n", "\n")
                    if content:len() > 0 and content:sub(-1) ~= "\n" then
                      count = count + 1
                    end
                    M._process_file(stats, excluded, file, count)
                  end
                end

                if stats.smallest.lines == math.huge then
                  stats.smallest = { name = "None", lines = 0 }
                end

                local sorted = {}
                for k, v in pairs(stats.lines_by_type) do
                  table.insert(sorted, { name = k, lines = v })
                end
                table.sort(sorted, function(a, b) return a.lines > b.lines end)
                stats.lines_by_type = sorted

                table.sort(
                  stats.top_files,
                  function(a, b) return a.lines > b.lines end
                )

                cb(stats)
              end)
            end
          )
        end
      )
    end
  )
end

return M
