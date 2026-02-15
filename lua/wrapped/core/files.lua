---@class Wrapped.Core.Files
local M = {}

---@return string path
local function get_path() return require("wrapped").config.path end

---@return Wrapped.FileStats stats
function M.get_stats()
  local config_path = get_path()
  local stats = { ---@type Wrapped.FileStats
    total_lines = 0,
    biggest = { name = "", lines = 0 },
    smallest = { name = "", lines = math.huge },
    lines_by_type = {},
  }
  local excluded = {} ---@type table<string, boolean>
  for _, ext in ipairs(require("wrapped").config.exclude_filetype or {}) do
    excluded[ext] = true
  end

  ---@param dir string
  ---@param cb function(path: string, name: string)
  local function walk_dir(dir, cb)
    for name, type in vim.fs.dir(dir) do
      local path = vim.fs.joinpath(dir, name)
      if type == "directory" and name ~= ".git" then
        walk_dir(path, cb)
      elseif type == "file" then
        cb(path, name)
      end
    end
  end

  walk_dir(config_path, function(path, name)
    if not (path:match "%.git[/\\]" or path:match "%.git$") then
      local filename = vim.fn.fnamemodify(name, ":t")
      local ext = filename:match "^%." and filename
        or vim.fn.fnamemodify(filename, ":e")
      ext = (ext == "" and "no ext" or ext):lower()

      if not excluded[ext] then
        local lines = 0
        local f = io.open(path, "rb")
        if f then
          for _ in f:lines() do
            lines = lines + 1
          end
          f:close()

          stats.total_lines = stats.total_lines + lines

          local rel_name = name
          if lines > stats.biggest.lines then
            stats.biggest = { name = rel_name, lines = lines }
          end
          if lines > 0 and lines < stats.smallest.lines then
            stats.smallest = { name = rel_name, lines = lines }
          end
          stats.lines_by_type[ext] = (stats.lines_by_type[ext] or 0) + lines
        end
      end
    end
  end)

  if stats.smallest.lines == math.huge then
    stats.smallest = { name = "None", lines = 0 }
  end

  local sorted = {} ---@type Wrapped.FileStat[]
  for k, v in pairs(stats.lines_by_type) do
    table.insert(sorted, { name = k, lines = v })
  end
  table.sort(sorted, function(a, b) return a.lines > b.lines end)
  stats.lines_by_type = sorted

  return stats
end

return M
