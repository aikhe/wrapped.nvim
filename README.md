# Wrapped

[![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

Visualize and review your Neovim configuration activity with stats, insights, history, and heatmaps.

![Wrapped Tokyonight](https://github.com/user-attachments/assets/e82fdcb7-96bb-443b-bd0c-46a0ed345793)
![Wrapped Fleur](https://github.com/user-attachments/assets/0e8e5e12-508a-4836-b87c-67797d98f890)

## Features

- **Progress Bars**: Track commits, plugins, total ever installed, and total lines.
- **Commit Heatmap**: A GitHub-style contribution graph with year cycling, month-colored columns, and intensity levels.
- **Plugin Insights**: Oldest/newest plugin age, total ever installed count, and a plugin growth chart over time.
- **File Statistics**: Biggest/smallest files, top 5 file types, top 5 files by line count.
- **Git Analytics**: Commit streaks, highest/lowest activity days, config lifetime, last change, and config size over time chart.
- **Config Changes Frequency**: A dot graph showing monthly commit frequency.
- **Visual Dashboard**: A beautiful, component-based UI powered by [`nvzone/volt`](https://github.com/nvzone/volt).

> [!IMPORTANT]
> This plugin is in it's early stage so I'd love to hear any feedbacks, issues, and contributions if you have any!~

## Installation

**Requirements**:

- **Neovim** >= 0.10.0
- [`nvzone/volt`](https://github.com/nvzone/volt) (UI framework dependency)
- A [Nerd Font](https://www.nerdfonts.com/) (for icons)

### Lazy

```lua
{
  "aikhe/wrapped.nvim",
  dependencies = { "nvzone/volt" },
  cmd = { "WrappedNvim" },
  opts = {},
}
```

## Usage

Run the following command to open the dashboard:

```vim
:WrappedNvim
```

## Mappings

| Key | Action    |
| --- | --------- |
| `<` | prev year |
| `>` | next year |

## Default Config

```lua
require("wrapped").setup({
  path = vim.fn.stdpath("config"), -- path to your neovim configuration
  border = false,
  size = {
    width = 120,
    height = 40,
  },
  exclude_filetype = {
    ".gitmodules",
  },
  cap = {
    commits = 1000,
    plugins = 100,
    plugins_ever = 200,
    lines = 10000,
  },
})
```

## How it Works

All data collection is fully async via `vim.system` callbacks and runs concurrently across three tasks. A loading screen is displayed until all tasks resolve, then the dashboard renders in a single pass.

### Processes

- **Git** (`core/git.lua`): Runs 5 concurrent `git` commands — `rev-list --count` for total commits, `git log --reverse` for first commit date, `git log --format=%ad` for config stats (streak calculation, highest/lowest day, monthly commit frequency, lifetime & last change), commit activity grouped by `ddmmyyyy` keys for the heatmap, and a sequential `git diff --shortstat` chain against the empty tree across ~50 sampled commits for the config size history.
- **Files** (`core/files.lua`): Uses `git diff --numstat` against the empty tree hash for per-file line counts of tracked files, plus `git ls-files --others` with `io.open` for untracked files. Aggregates total lines, biggest/smallest file, lines by extension, and top files.
- **Plugins** (`core/plugins.lua`): Scans `git log -p` patches for `user/repo` patterns in added lines to count total ever installed plugins and build a growth timeline. Queries `lazy.nvim` for current plugin list, then sequentially runs `git log -1 --format=%at` in each plugin directory to find the oldest and newest plugins.
