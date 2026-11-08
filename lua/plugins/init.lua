return {
  {
    "stevearc/conform.nvim",
    opts = require "configs.conform",
  },

  -- Markdown preview in Browser
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
    enabled = false,
  },

  -- Markdown preview in Terminal (better)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
    config = function()
      require("render-markdown").setup {
        enabled = true,
        file_types = { "markdown" },
        -- you can add more config keys here as desired
      }
    end,
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- A pretty list for showing diagnostics, references, telescope results, quickfix and location lists
  -- to help you solve all the trouble your code is causing.
  {
    "folke/trouble.nvim",
    opts = require("configs.trouble").opts,
    cmd = require("configs.trouble").cmd,
    keys = require("configs.trouble").keys,
  },

  -- plug-in which provides support for expanding abbreviations similar to emmet.
  -- action key : <C-y> + ,
  {
    "mattn/emmet-vim",
    ft = require("configs.emmet").ft,
  },

  -- Vim syntax highlighting for Blade templates (Laravel 4+).
  {
    "jwalton512/vim-blade",
    ft = "blade",
  },

  -- A comprehensive Laravel development plugin for Neovim
  {
    "adibhanna/laravel.nvim",
    keys = require("configs.laravel").keys,
    config = require("configs.laravel").config,

    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
    },
  },

  -- Highly experimental plugin that completely replaces the UI for messages, cmdline and the popupmenu.
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = require "configs.noice",

    dependencies = {
      "MunifTanjim/nui.nvim",
      { "rcarriga/nvim-notify", opts = { timeout = 2000 } },
    },
  },

  -- Lspsaga: richer LSP UI (peek definition, file outline)
  -- Use: gp = peek definition in a popup, <leader>o = outline of the file
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      lightbulb = { enable = false },
      symbol_in_winbar = { enable = false },
    },
  },

  -- For autoSave
  {
    "okuuva/auto-save.nvim",
    cmd = "ASToggle",
    event = { "InsertLeave", "TextChanged" },
    opts = {
      -- add yours options here
    },
  },

  -- Break bad habits, master Vim motions
  {
    "m4xshen/hardtime.nvim",
    lazy = true,
    enabled = true,
    opts = {},

    dependencies = { "MunifTanjim/nui.nvim" },
  },
  -- :Hardtime enable enable Hardtime
  -- :Hardtime disable disable Hardtime
  -- :Hardtime toggle toggle Hardtime

  -- flash.nvim lets you navigate your code with search labels, enhanced character motions,
  -- and Treesitter integration.
  {
    "folke/flash.nvim",
    event = require("configs.flash").event,
    opts = require("configs.flash").opts,
    keys = require("configs.flash").keys,
  },

  -- Todos + notes in a popup from anywhere (keys and folder: configs/notes.lua)
  {
    "backdround/global-note.nvim",
    cmd = { "Todo", "Notes" },
    keys = require("configs.notes").keys,
    opts = require("configs.notes").global_note,
  },
  -- Nice checkboxes, priorities and archive inside todo.md / notes.md
  {
    "bngarren/checkmate.nvim",
    ft = "markdown",
    opts = require("configs.notes").checkmate,
  },

  -- test new blink
  { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local opts = require("configs.ts").opts or {}
      if opts.ensure_installed then
        require("nvim-treesitter").install(opts.ensure_installed)
      end
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
}
