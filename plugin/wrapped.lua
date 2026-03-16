if vim.g.wrapped_loaded == 1 then return end

vim.g.wrapped_loaded = 1

-- Default keybinding (can be overridden in setup())
vim.keymap.set("n", "<leader>gw", ":WrappedNvim<CR>", { desc = "Open Wrapped dashboard" })

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

-- vim.api.nvim_create_user_command(
--   "WrappedProject",
--   function() require("wrapped").run() end,
--   {}
-- )
