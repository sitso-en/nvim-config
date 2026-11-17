# nvim-config

My Neovim setup, built on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) and set up to feel like VS Code.
I use it for **Python/Django**, **Java/Spring Boot**, **Next.js** and **Node.js**.

## How it's organised

| File | What it is |
|---|---|
| `init.lua` | Stock kickstart. Only two lines changed: the Nerd Font switch is on, and the last line loads `snacks.lua`. |
| `lua/custom/snacks.lua` | **All my own settings.** It loads last, so it overrides kickstart's defaults. |
| `nvim-pack-lock.json` | The exact plugin versions, so a fresh install gets the same versions. |

Keeping `init.lua` close to stock makes it easy to pull in kickstart updates (see [Updating kickstart](#updating-kickstart)).

## What's set up

**Look and feel**
- Built-in `quiet` colorscheme (dark), JetBrains Mono font (set in kitty)
- File sidebar (neo-tree) with **Files** and **Git** tabs, showing the current file and changed files
- Tabs for open files, indent guides, and a sticky header that keeps the current function/class name visible

**Editing**
- VS Code shortcuts: undo, redo, copy, paste, save, find file, search project
- **Auto-save** about 1 second after you stop editing, and when you switch files or apps
- **Format on save** (Ctrl+S / `:w` only; auto-saves don't reformat)
- **Organize imports**: add missing, remove unused, sort
- Auto-closing brackets and quotes
- AI suggestions (GitHub Copilot)

**Languages**

| Language | Autocomplete / errors | Formatting | Debugging | Tests |
|---|---|---|---|---|
| Python / Django | basedpyright (VS Code-style: real problems only) | ruff | debugpy (incl. Django runserver) | pytest / Django test runner |
| JavaScript / TypeScript / Next.js / Node | ts_ls, ESLint, Tailwind | prettier | js-debug (launch file / attach to Next.js) | Jest, Vitest |
| Java / Spring Boot | jdtls (via nvim-jdtls) | jdtls | java-debug | JUnit |
| YAML, docker-compose, Dockerfile, JSON, HTML, CSS, SQL | language servers + SchemaStore | prettier (web files) | | |

The Python interpreter comes from the project's `.venv` / `venv` automatically.

**Tools inside Neovim**
- Terminal at the bottom (toggle it on and off)
- lazygit in a floating window
- Problems panel listing every error and warning
- Database viewer for Postgres and SQLite (vim-dadbod), with SQL autocomplete
- `.http` request runner for testing APIs, with `{{VARIABLES}}` filled from the project's `.env`
- Reopens the files you had open last time when you run `nvim` or `nvim .` in a project

## Keys

`Space` is the leader key. Press it and wait to see a menu of everything.

| Key | Does |
|---|---|
| `Ctrl+S` | Save and format |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Ctrl+C` / `Ctrl+V` | Copy / paste (system clipboard). Block-select moved to `Ctrl+Q` |
| `Ctrl+P` | Find a file |
| `Ctrl+Shift+F` | Search text in the project |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab (also `Shift+L` / `Shift+H`) |
| `Space x` | Close tab |
| `\` | Toggle the file sidebar |
| `Alt+Shift+O` | Organize imports (also `Space o`) |
| `gra` | Quick fixes for the current line |
| `grd` / `grr` / `grn` | Go to definition / find references / rename |
| `Ctrl+Shift+M` | Problems panel (also `Space p`) |
| ``Ctrl+` `` | Toggle the terminal (also `Space t t`) |
| `Space g g` | lazygit |
| `Space D` | Database viewer (`A` adds a connection, `Space S` runs a query) |
| `Enter` | In a `.http` file: send the request under the cursor |
| `F9` / `F5` | Toggle breakpoint / start or continue debugging |
| `F10` / `F11` / `Shift+F11` | Step over / into / out. `Shift+F5` stops |
| `Space r t` / `r f` / `r a` | Run nearest test / this file's tests / all tests |
| `Space r s` / `r o` / `r d` | Test list / test output / debug nearest test |
| `Tab` | Accept a Copilot suggestion |

The full list, with notes, is at the top of [`lua/custom/snacks.lua`](lua/custom/snacks.lua).

## Install on a new machine

Requirements: **Neovim 0.12+**, `git`, `gcc`, `make`, `tree-sitter` CLI, `ripgrep`, `curl`, `jq`, `node`/`npm`, Python 3, Java 21+ (for jdtls), and [lazygit](https://github.com/jesseduffield/lazygit). Optional: `psql` / `sqlite3` for the database viewer.

```sh
git clone https://github.com/sitso-en/nvim-config.git ~/.config/nvim
nvim
```

On first start, plugins install automatically, and Mason installs the language servers, formatters and debuggers in the background (see `:Mason`). Restart once they're done.

Then, one time:
- `:Copilot auth` to sign in to GitHub Copilot (the free plan works)
- `:NeotestJava setup` to download the JUnit runner for Java tests

**Terminal:** this is set up for [kitty](https://sw.kovidgoyal.net/kitty/). For `Ctrl+Tab`, `Ctrl+Shift+F` and `Ctrl+Shift+M` to reach Neovim, kitty needs these lines (Neovim tells kitty when it's focused):

```conf
map --when-focus-on var:in_editor ctrl+tab
map --when-focus-on var:in_editor ctrl+shift+tab
map --when-focus-on var:in_editor ctrl+shift+f
map --when-focus-on var:in_editor ctrl+shift+m
```

**lazygit:** to open files from lazygit in this Neovim, add this to `~/.config/lazygit/config.yml`:

```yaml
os:
  editPreset: 'nvim-remote'
```

## Testing APIs with `.http` files

```http
@base = http://localhost:8000

### Login
POST {{base}}/api/auth/login/
Content-Type: application/json

{ "email": "me@example.com", "password": "{{TEST_PASSWORD}}" }

###
GET {{base}}/api/orders/
Authorization: Bearer {{TOKEN}}
```

Put the cursor on a request and press `Enter`. The response opens on the right, with JSON pretty-printed.
`{{NAME}}` is filled from `@NAME = ...` lines in the file, then the project's `.env`, then environment variables.

## Updating kickstart

The original kickstart repo is the `upstream` remote:

```sh
git fetch upstream
git merge upstream/master
```

My changes are almost all in `lua/custom/snacks.lua`, so merges rarely conflict.

## Credits

Based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) (MIT, see [LICENSE.md](LICENSE.md)).
Kickstart's original guide is in its repo's [README](https://github.com/nvim-lua/kickstart.nvim#readme).
