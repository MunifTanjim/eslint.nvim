# eslint.nvim

ESLint plugin for Neovim's built-in LSP client.

## Requirements

- [Neovim 0.5.0](https://github.com/neovim/neovim/releases/tag/v0.5.0)
- [`neovim/nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)
- [`jose-elias-alvarez/null-ls`](https://github.com/jose-elias-alvarez/null-ls.nvim)

## Installation

Install the plugins with your preferred plugin manager. For example, with [`vim-plug`](https://github.com/junegunn/vim-plug):

```vim
Plug 'neovim/nvim-lspconfig'
Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'MunifTanjim/eslint.nvim'
```

## Setup

`eslint.nvim` needs to be initialized with the `require("eslint").setup()` function.
It recommended to initialize it inside lspconfig `tsserver`'s `on_attach` callback.

For example:

```lua
local lspconfig = require("lspconfig")
local null_ls = require("null-ls")
local eslint = require("eslint")

null_ls.setup()

lspconfig.tsserver.setup({
  on_attach = function(client, bufnr)
    -- other stuffs

    eslint.setup({
      bin = 'eslint', -- or `eslint_d`
      code_actions = {
        enable = true,
        disable_rule_comment = {
          enable = true,
        },
      },
      diagnostics = {
        enable = true,
      },
    })

    -- other stuffs
  end
})
```

## Acknowledgements

- [`jose-elias-alvarez/nvim-lsp-ts-utils`](https://github.com/jose-elias-alvarez/nvim-lsp-ts-utils)
  most of the stuffs are extracted from this plugin.

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
