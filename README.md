# nvim-ghrelease

[![CI](https://github.com/mesirendon/nvim-ghrelease/actions/workflows/ci.yml/badge.svg)](https://github.com/mesirendon/nvim-ghrelease/actions/workflows/ci.yml)

Create GitHub releases from inside Neovim, driven by the [`gh`](https://cli.github.com) CLI.

Instead of `gh`'s terminal prompts, `nvim-ghrelease` lists your existing releases,
suggests the next semantic version, and asks each question `gh release create` asks.
Free-text answers (tag, title, release notes) open in a dedicated **buffer per step** —
edit, then `:wq` to move to the next question. When every answer is collected it runs
`gh release create` and reports the new release URL.

## Features

- Lists current releases for context before you start.
- Suggests the next version with a semver bump menu (`major` / `minor` / `patch` / `prerelease` / `custom`).
- Buffer-per-step editing: `:wq` saves the answer and advances.
- Release-notes sources mirroring gh: write your own, GitHub-generated template, commit-log template, or leave blank.
- Final `Publish / Save as draft / Cancel` step, plus a prerelease question.
- Fully async (`vim.system`), no blocking of the editor.

## Requirements

- Neovim **0.10+** (needs `vim.system`; the plugin refuses to load and warns on older versions). Tested in CI on 0.10, 0.11, stable, and nightly.
- The GitHub CLI `gh`, installed and authenticated: `gh auth login`
- Run the command from within a GitHub repository

## Installation

### lazy.nvim

```lua
{
  "mesirendon/nvim-ghrelease",
  -- Load at startup so the default keymap (<leader>gr) is registered.
  event = "VeryLazy",
  opts = {}, -- optional; see Configuration
}
```

> `setup()` (via `opts`) is what installs the default keymaps, so the plugin must
> be loaded for them to exist. If you prefer to lazy-load only on the keypress,
> disable the built-in maps and let lazy own the key:
>
> ```lua
> {
>   "mesirendon/nvim-ghrelease",
>   opts = { keymaps = false },
>   keys = { { "<leader>gr", "<cmd>GhRelease<cr>", desc = "GitHub Release: create" } },
> }
> ```

### packer.nvim

```lua
use({
  "mesirendon/nvim-ghrelease",
  config = function()
    require("ghrelease").setup()
  end,
})
```

### vim-plug

```vim
Plug 'mesirendon/nvim-ghrelease'
" then, in your Lua config:
lua require('ghrelease').setup()
```

### mini.deps

```lua
add({ source = "mesirendon/nvim-ghrelease" })
```

Calling `setup()` is optional — the `:GhRelease` command is available as soon as the
plugin is on the runtimepath.

## Usage

Run inside a GitHub repository:

```
:GhRelease
```

or from Lua:

```lua
require("ghrelease").create()
```

Then follow the steps:

1. **Existing releases** are shown — press `<CR>`, `q`, or `<Esc>` to continue.
2. **Version menu** — pick a bump or `custom`.
3. **Tag** buffer (pre-filled) — edit, `:wq`.
4. **Title** buffer.
5. **Notes source** — own / generated / commit-log / blank.
6. **Notes** buffer (pre-filled per source), unless blank.
7. **Prerelease?** — yes/no.
8. **Submit** — Publish / Save as draft / Cancel.

In any editing buffer, `:wq` accepts and continues; `:q` keeps whatever is shown.

## Keymaps

`setup()` installs one default keymap, sitting in the `<leader>g` (git) family:

| Keys | Mode | Action | Command |
| --- | --- | --- | --- |
| `<leader>gr` | `n` | GitHub Release: create | `:GhRelease` |

The description shows up in [which-key](https://github.com/folke/which-key.nvim)
automatically under your git group.

### Overriding the defaults

Pass a `keymaps` table to `setup()` (or `opts` in lazy.nvim). Each key is an action
name; the value is the normal-mode `lhs`, or `false` to skip that action:

```lua
require("ghrelease").setup({
  keymaps = {
    create = "<leader>oR", -- remap "create" to <leader>oR
  },
})
```

Disable a single action:

```lua
require("ghrelease").setup({
  keymaps = { create = false },
})
```

Disable **all** default keymaps and map it yourself:

```lua
require("ghrelease").setup({ keymaps = false })

vim.keymap.set("n", "<leader>R", "<cmd>GhRelease<cr>",
  { desc = "GitHub Release: create", silent = true })
```

## Configuration

Defaults, with overrides passed to `setup()`:

```lua
require("ghrelease").setup({
  list_limit   = 30,       -- releases shown in the context view
  default_bump = "patch",  -- highlighted first in the version menu
  tag_prefix   = "v",      -- prefix for the suggested first tag
  first_tag    = "v0.1.0", -- seed tag when the repo has no releases
  win          = "float",  -- editing window style: "float" | "split" | "vsplit"
  height       = 12,       -- editing buffer height / float rows
  keymaps      = {         -- default keymaps; false disables all (see Keymaps)
    create = "<leader>gr",
  },
})
```

The choice menus use `vim.ui.select`, so they integrate automatically with
[dressing.nvim](https://github.com/stevearc/dressing.nvim), telescope-ui-select, etc.

## Development

Run the pure version-logic tests headlessly:

```sh
nvim --headless -l tests/version_spec.lua
```

## License

MIT
