return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",

  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },

  lazy = false,

  opts = {
    filesystem = {
      window = {
        width = 20,

        mappings = {
          ["A"] = {
            "add",
            config = {
              show_path = "none",
            },
          },

          ["<C-S-a>"] = "add_directory",

          ["D"] = "delete",

          ["r"] = "rename",

          ["m"] = "move",

          ["c"] = "copy",
        },
      },
    },
  },
}
