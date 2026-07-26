return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },

    {
        "williamboman/mason-lspconfig.nvim",
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",
                    "basedpyright",
                    "html",
                    "cssls",
                    "ts_ls",
                },
            })
        end,
    },

    {
        "neovim/nvim-lspconfig",
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            local servers = {
                lua_ls = {
                    settings = {
                        Lua = {
                            diagnostics = {
                                globals = { "vim" },
                            },
                        },
                    },
                },

                basedpyright = {},

                html = {},

                cssls = {},

                ts_ls = {},
            }

            for server, opts in pairs(servers) do
                opts.capabilities = capabilities

                vim.lsp.config(server, opts)
                vim.lsp.enable(server)
            end

            -- LSP Keymaps
            vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover Documentation" })
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to Implementation" })
            vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Show References" })
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename Symbol" })
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Actions" })
            vim.keymap.set("n", "<leader>f", function()
                vim.lsp.buf.format({ async = true })
            end, { desc = "Format Buffer" })
        end,
    },
}
