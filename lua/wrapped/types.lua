---@meta

---@class WrappedConfig
---@field path string|nil
---@field border boolean
---@field size { width: integer, height: integer }
---@field exclude_filetype string[]
---@field cap { commits: integer, plugins: integer, plugins_ever: integer, lines: integer }

---@class Wrapped.FileStat
---@field name string
---@field lines number

---@class Wrapped.FileStats
---@field total_lines integer
---@field biggest Wrapped.FileStat
---@field smallest Wrapped.FileStat
---@field lines_by_type Wrapped.FileStat[]

---@class Wrapped.PluginInfo
---@field name string
---@field date integer

---@class Wrapped.PluginHistory
---@field total_ever_installed integer
---@field oldest_plugin Wrapped.PluginInfo|nil
---@field newest_plugin Wrapped.PluginInfo|nil

---@class Wrapped.ConfigStats
---@field longest_streak integer
---@field last_change string
---@field lifetime string
---@field shortest_msg string
---@field longest_msg string
