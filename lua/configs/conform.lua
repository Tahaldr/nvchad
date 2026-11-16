local front_end_fmt = "prettierd"

local options = {
  formatters_by_ft = {
    -- Frontend
    html = { front_end_fmt },
    twig = { front_end_fmt },
    css = { front_end_fmt },
    scss = { front_end_fmt },
    less = { front_end_fmt },
    javascript = { front_end_fmt },
    javascriptreact = { front_end_fmt },
    typescript = { front_end_fmt },
    typescriptreact = { front_end_fmt },
    json = { front_end_fmt },
    yaml = { front_end_fmt },

    -- PHP
    php = { "pretty-php" },
    blade = { "blade-formatter" },

    -- Python
    python = { "ruff_organize_imports", "ruff_format" },

    -- Java
    java = { "google-java-format" },

    -- Lua
    lua = { "stylua" },
  },

  format_on_save = {
    lsp_fallback = true,
    timeout_ms = 3000,
  },
}

return options
