---@meta

---@class Wrapped.Config
---@field border boolean
---@field size {width: number, height: number}
---@field exclude_filetype string[]

---@class Wrapped.FileStat
---@field name string
---@field lines number

---@class Wrapped.FileStats
---@field total_lines number
---@field biggest Wrapped.FileStat
---@field smallest Wrapped.FileStat
---@field lines_by_type Wrapped.FileStat[]

---@class Wrapped.PluginInfo
---@field name string
---@field date number

---@class Wrapped.PluginHistory
---@field total_ever_installed number
---@field oldest_plugin Wrapped.PluginInfo?
---@field newest_plugin Wrapped.PluginInfo?
