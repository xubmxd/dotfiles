vim.g.mapleader = " "

local keymap = vim.keymap.set

keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>")
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>")
keymap("n", "<leader>e", ':Neotree toggle<CR>')
