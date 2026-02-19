if vim.g.wrapped_loaded == 1 then return end

vim.g.wrapped_loaded = 1

vim.api.nvim_create_user_command(
  "NvimWrapped",
  function() require("wrapped").run() end,
  {}
)

vim.api.nvim_create_user_command(
  "WrappedNvim",
  function() require("wrapped").run() end,
  {}
)

vim.api.nvim_create_user_command(
  "WrappedProject",
  function() require("wrapped").run() end,
  {}
)
