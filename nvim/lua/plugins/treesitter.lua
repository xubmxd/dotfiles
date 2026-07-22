return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",

    config = function()
        require("nvim-treesitter.config").setup({
            ensure_installed = {
                "lua",
                "vim",
                "vimdoc",
                "bash",
                "python",
                "go",
                "html",
                "css",
                "javascript",
                "json",
                "yaml",
                "markdown",
                "markdown_inline",
            },

            auto_install = true,
            sync_install = false,

            highlight = {
                enable = true,
            },

            indent = {
                enable = true,
            },
        })
    end,
}
