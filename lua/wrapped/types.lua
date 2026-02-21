---@meta

-- config

---@class WrappedConfig
---@field path string|nil
---@field border boolean|string|string[]
---@field size { width: integer, height: integer }
---@field exclude_filetype string[]
---@field cap { commits: integer, plugins: integer, plugins_ever: integer, lines: integer }

-- state

---@class Wrapped.State
---@field config WrappedConfig
---@field xpad integer
---@field ypad integer
---@field ns integer
---@field buf integer|nil
---@field win integer|nil
---@field commit_activity table<string, integer>|nil
---@field heatmap_year integer
---@field first_commit_year integer|nil

-- core data

---@class Wrapped.FileStat
---@field name string
---@field lines number

---@class Wrapped.FileStats
---@field total_lines integer
---@field biggest Wrapped.FileStat
---@field smallest Wrapped.FileStat
---@field lines_by_type? Wrapped.FileStat[]
---@field top_files? Wrapped.FileStat[]

---@class Wrapped.PluginInfo
---@field name string
---@field dir? string
---@field date integer

---@class Wrapped.PluginGrowth
---@field date string
---@field count integer

---@class Wrapped.PluginHistory
---@field total_ever_installed integer
---@field oldest_plugin Wrapped.PluginInfo|nil
---@field newest_plugin Wrapped.PluginInfo|nil
---@field growth Wrapped.PluginGrowth[]|nil

---@class Wrapped.ConfigStats
---@field longest_streak integer
---@field longest_streak_start string|nil
---@field longest_streak_end string|nil
---@field highest_day { count: integer, date: string }|nil
---@field lowest_day { count: integer, date: string }|nil
---@field commit_history integer[]
---@field last_change string
---@field lifetime string

---@class Wrapped.SizeHistory
---@field values integer[]
---@field labels string[]

-- results

---@class Wrapped.GitStats
---@field total_count? integer|string
---@field first_commit_date? string
---@field config_stats? Wrapped.ConfigStats
---@field commit_activity? table<string, integer>
---@field size_history? Wrapped.SizeHistory

---@class Wrapped.Results
---@field git? Wrapped.GitStats
---@field files? Wrapped.FileStats
---@field plugins? Wrapped.PluginHistory
