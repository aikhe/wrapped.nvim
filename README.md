# Wrapped

Visualize and review your Neovim configuration activity with stats, insights, history, and heatmaps.

![wrapped](https://github.com/user-attachments/assets/624d7d7f-5eb2-447d-bb8b-5f24b3adbbe9)
![wrapped border](https://github.com/user-attachments/assets/b50724de-0576-4034-9cd0-bc86eb427139)

## Features

- **Git Analytics**: Visualize your commit history, streaks, and total activity.
- **Commit Heatmap**: A contribution graph view.
- **Plugin Insights**: Track your plugin usage, installation history, and total count.
- **File Statistics**: Analyze your codebase with top file types and size growth over time.
- **Visual Dashboard**: A beautiful, component-based UI powered by [`nvzone/volt`](https://github.com/nvzone/volt).

> [!IMPORTANT]
> This plugin is currently a **prototype** and is **very unstable**, it might not work to some.
> I made this version to have a quick iteration and see what I can do. But ofcourse future updates will aim to be stable, optimized, bug-free, compatible, and fast.
> I’d love to hear any feedbacks, issues, and contributions if you have any.

## Installation

**Requirements**:

- **Neovim** >= 0.9.0
- [`nvzone/volt`](https://github.com/nvzone/volt) (UI framework dependency)
- A [Nerd Font](https://www.nerdfonts.com/) (for icons)

### Lazy

```lua
{
  "aikhe/wrapped.nvim",
  dependencies = { "nvzone/volt", "nvim-lua/plenary.nvim" },
  cmd = { "NvimWrapped" },
  opts = {},
}
```

## Usage

Run the following command to open the dashboard:

```vim
:NvimWrapped
```

## Mappings

| Key | Action    |
| --- | --------- |
| `<` | prev year |
| `>` | next year |

## Default Config

```lua
require("wrapped").setup({
  path = vim.fn.stdpath("config"), -- path to your neovim configuration (defaults to nvim config)
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

> **Note**: Lots of inneffiency since im mostly new to this stuff and still learning but I'll make sure to iterate on it and make better changes.

- **Git Analytics**: Aggregates history via `git log` and `git rev-list`. Streaks are calculated by tracking consecutive days with commit activity. The "Config Size" chart samples your commit history and performs a `git diff --shortstat` against an empty tree at each point to estimate line growth.
- **Plugin Tracking**:
  - **Current**: Interface directly with the `lazy.nvim` API for active plugin counts.
  - **Total Ever**: Scans `git log` patches for new plugin definitions (specifically within `lua/plugins`) to estimate how many unique plugins you've tried.
  - **Age**: Inspects the local git history of each installed plugin to find the oldest and newest additions to your current setup.
- **File Analysis**: Recursively scans your configuration directory using `plenary.scandir`. It parses files to calculate total line counts, distribution by file extension (e.g., Lua, Vim, Markdown), and identifies your largest/smallest configuration files.
- **Plenary Integration**:
  - **Async Operations**: Leverages `plenary.job` to run git operations in parallel when fetching plugin ages, using `vim.wait` for non-blocking synchronization.
  - **Performance**: Utilizes `plenary.scandir` for efficient file system parsing and `plenary.job` for all external git process management.
