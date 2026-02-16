---@class Wrapped.Core.Files
local M = {}

---@return string path
local function get_path() return require("wrapped").config.path end

---@param cb fun(stats: Wrapped.FileStats)
function M.get_stats_async(cb)
  local config_path = get_path()
  local excluded = {}
  for _, ext in ipairs(require("wrapped").config.exclude_filetype or {}) do
    excluded[ext] = true
  end

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
            }
          end
        )
        return
      end

      -- git diff --numstat outputs: <added> <removed> <file> per line
      -- against empty tree, added = total lines in file
      vim.system(
        { "git", "diff", "--numstat", empty_tree, "HEAD" },
        { cwd = config_path, text = true },
        function(diff_out)
          vim.schedule(function()
            local stats = { ---@type Wrapped.FileStats
              total_lines = 0,
              biggest = { name = "", lines = 0 },
              smallest = { name = "", lines = math.huge },
              lines_by_type = {},
            }

            local lines =
              vim.split(diff_out.stdout or "", "\n", { trimempty = true })
            for _, line in ipairs(lines) do
              local added, _, file = line:match "^(%d+)%s+(%d+)%s+(.+)$"
              if added and file then
                local count = tonumber(added, 10) or 0
                local ext = (file:match "%.([^%.]+)$" or "no ext"):lower()

                if not excluded[ext] then
                  stats.total_lines = stats.total_lines + count
                  if count > stats.biggest.lines then
                    stats.biggest = { name = file, lines = count }
                  end
                  if count > 0 and count < stats.smallest.lines then
                    stats.smallest = { name = file, lines = count }
                  end
                  stats.lines_by_type[ext] = (stats.lines_by_type[ext] or 0)
                    + count
                end
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

            cb(stats)
          end)
        end
      )
    end
  )
end

return M
