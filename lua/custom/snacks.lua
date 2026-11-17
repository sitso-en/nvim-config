-- ============================================================
-- snacks.lua: MY personal Neovim settings
--
-- init.lua is the stock kickstart config. It loads this file as its very
-- last step, so anything here wins over kickstart's defaults.
-- Put all your own changes in this file.
--
-- CHEAT SHEET (<leader> is the Space key)
--   Ctrl+S          save now (also tidies/formats the file)
--   Ctrl+Z / Ctrl+Y undo / redo
--   Ctrl+C          copy selection (or the whole line if nothing is selected)
--   Ctrl+V          paste            (block-select is now Ctrl+Q)
--   Alt+Shift+O     organize imports: add missing ones, remove unused ones, sort them
--                   (also Space o; works in Python, JS/TS and Java)
--   gra             quick fixes for the line under the cursor (like VS Code's lightbulb)
--   \               open / close the file sidebar
--   Ctrl+` or Space t t   open / close the terminal at the bottom
--   F9 or Space b   set / remove a breakpoint
--   F5              start debugging / continue      Shift+F5  stop
--   F10 / F11 / Shift+F11   step over / step into / step out
--   Files are saved automatically (formatting only happens on Ctrl+S / :w).
--
--   Ctrl+P          find a file by name             (also Space s f)
--   Ctrl+Shift+F    search text in the whole project (also Space s g)
--   Ctrl+Tab / Ctrl+Shift+Tab   next / previous tab  (also Shift+L / Shift+H)
--   Space x         close the current tab
--   Ctrl+Shift+M    Problems panel: all errors/warnings (also Space p)
--   Space g g       lazygit (git: stage, commit, push, branches...)
--   Space D         database viewer
--   Enter           in a .http file: send the request under the cursor (also Space R s)
--   Space r t / r f / r a   run the nearest test / this file's tests / all tests
--   Space r s / r o         test list panel / test output     Space r d  debug nearest test
--   Tab             accept an AI (Copilot) suggestion  (first run :Copilot auth once)
-- ============================================================

local mason_bin = vim.fn.stdpath 'data' .. '/mason/bin'

-- Find the Python interpreter for a project: its .venv / venv folder,
-- otherwise the virtualenv that was active when nvim started, otherwise system python.
local function find_python(root)
  root = root or vim.fn.getcwd()
  for _, dir in ipairs { '.venv', 'venv' } do
    local candidate = root .. '/' .. dir .. '/bin/python'
    if vim.uv.fs_stat(candidate) then return candidate end
  end
  if vim.env.VIRTUAL_ENV then return vim.env.VIRTUAL_ENV .. '/bin/python' end
  return vim.fn.exepath 'python3'
end

-- ============================================================
-- [[ Colorscheme ]]
-- Neovim's built-in 'quiet' theme, dark version.
-- (kickstart loads tokyonight first; this replaces it.)
-- ============================================================
vim.o.background = 'dark'
vim.cmd.colorscheme 'quiet'

-- ============================================================
-- [[ Tools to install ]]
-- Installed automatically through Mason (see :Mason) if missing.
-- ============================================================
local mason_packages = {
  -- Python
  'basedpyright', -- autocomplete, go-to-definition, errors, auto-imports (same engine as VS Code's Pylance)
  'ruff', -- formatting + import cleanup
  'debugpy', -- debugger
  -- JavaScript / TypeScript (Node.js, Next.js)
  'typescript-language-server', -- autocomplete, go-to-definition, errors
  'eslint-lsp', -- linting (uses the project's own eslint config)
  'tailwindcss-language-server', -- Tailwind class autocomplete (only in Tailwind projects)
  'prettierd', -- formatting
  'js-debug-adapter', -- debugger
  -- Java (Spring Boot)
  'jdtls', -- autocomplete, errors, formatting, imports
  'java-debug-adapter', -- debugger
  -- Other file types
  'yaml-language-server', -- .yml / .yaml (incl. docker-compose, GitHub Actions)
  'docker-compose-language-service', -- docker-compose.yml extras
  'dockerfile-language-server', -- Dockerfile
  'json-lsp', -- .json (package.json, tsconfig.json, ...)
  'html-lsp', -- HTML / Django templates
  'css-lsp', -- CSS / SCSS
  'sqlls', -- .sql
}

local registry_ok, registry = pcall(require, 'mason-registry')
if registry_ok then
  registry.refresh(function()
    for _, name in ipairs(mason_packages) do
      local pkg_ok, pkg = pcall(registry.get_package, name)
      if pkg_ok and not pkg:is_installed() then pkg:install() end
    end
  end)
end

-- ============================================================
-- [[ VS Code style shortcuts ]]
-- ============================================================
local map = vim.keymap.set

-- Undo / redo
map('n', '<C-z>', 'u', { desc = 'Undo' })
map('i', '<C-z>', '<C-o>u', { desc = 'Undo' })
map('v', '<C-z>', '<Esc>u', { desc = 'Undo' })
map('n', '<C-y>', '<C-r>', { desc = 'Redo' })
map('i', '<C-y>', '<C-o><C-r>', { desc = 'Redo' })
map('v', '<C-y>', '<Esc><C-r>', { desc = 'Redo' })

-- Copy / paste (uses the system clipboard, so it works with other apps too)
map('v', '<C-c>', '"+y', { desc = 'Copy selection' })
map('n', '<C-c>', '"+yy', { desc = 'Copy line' })
map('n', '<C-v>', '"+P', { desc = 'Paste' })
map('v', '<C-v>', '"+P', { desc = 'Paste over selection' })
map('i', '<C-v>', '<C-r><C-o>+', { desc = 'Paste' })
map('c', '<C-v>', '<C-r>+', { desc = 'Paste' })
-- Ctrl+V used to start block selection; that is now Ctrl+Q (Vim's built-in alternative).

-- Save
map({ 'n', 'i', 'v' }, '<C-s>', '<Cmd>write<CR>', { desc = 'Save file' })

-- ============================================================
-- [[ Auto-save ]]
-- Saves a file about 1 second after you stop editing it, when you leave it,
-- and when you switch to another app. Auto-saves do NOT reformat your code
-- (that would move text around while you work); Ctrl+S / :w does.
-- ============================================================
local autosaving = false

local function autosave(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local bo = vim.bo[buf]
  if bo.buftype ~= '' or not bo.modifiable or bo.readonly or not bo.modified then return end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' or vim.fn.isdirectory(vim.fn.fnamemodify(name, ':h')) == 0 then return end
  autosaving = true
  vim.api.nvim_buf_call(buf, function() vim.cmd 'silent! lockmarks update' end)
  autosaving = false
end

local autosave_timer = vim.uv.new_timer()
local autosave_group = vim.api.nvim_create_augroup('snacks-autosave', { clear = true })

vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
  group = autosave_group,
  callback = function(args)
    autosave_timer:stop()
    autosave_timer:start(1000, 0, vim.schedule_wrap(function() autosave(args.buf) end))
  end,
})

vim.api.nvim_create_autocmd('BufLeave', {
  group = autosave_group,
  callback = function(args) autosave(args.buf) end,
})

vim.api.nvim_create_autocmd({ 'FocusLost', 'VimLeavePre' }, {
  group = autosave_group,
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      autosave(buf)
    end
  end,
})

-- ============================================================
-- [[ Formatting ]]
-- Tidies code when you save with Ctrl+S or :w.
-- Uses the project's own config (pyproject.toml, .prettierrc, ...) when present.
-- To turn it off for a while: :let g:disable_format_on_save = 1
-- ============================================================
local prettier = { 'prettierd', 'prettier', stop_after_first = true }

require('conform').setup {
  notify_on_error = false,
  format_on_save = function()
    if autosaving or vim.g.disable_format_on_save == 1 then return nil end
    return { timeout_ms = 3000 }
  end,
  formatters = {
    -- Removes unused imports and sorts imports (used by Alt+Shift+O)
    ruff_imports = {
      command = 'ruff',
      args = { 'check', '--fix', '--select', 'F401,I', '--exit-zero', '--no-cache', '--stdin-filename', '$FILENAME', '-' },
      stdin = true,
    },
  },
  default_format_opts = {
    lsp_format = 'fallback', -- Java (and anything not listed below) is formatted by its language server
  },
  formatters_by_ft = {
    python = { 'ruff_organize_imports', 'ruff_format' },
    javascript = prettier,
    javascriptreact = prettier,
    typescript = prettier,
    typescriptreact = prettier,
    json = prettier,
    jsonc = prettier,
    css = prettier,
    scss = prettier,
    html = prettier,
    yaml = prettier,
  },
}

-- ============================================================
-- [[ Language servers ]]
-- Autocomplete, go-to-definition, errors and warnings (linting).
-- ============================================================

-- Python: basedpyright, set up like VS Code's default Python setup:
--   * shows real problems only: undefined names and imports that don't exist
--   * unused imports/variables are just shown faded, not as warnings
--   * no strict type-checking (set typeCheckingMode to 'basic' or 'standard' if you ever want it)
-- It uses the project's .venv automatically.
-- To pick a different interpreter while working: :LspPyrightSetPythonPath /path/to/python
vim.lsp.config('basedpyright', {
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = 'off',
        diagnosticSeverityOverrides = {
          reportUndefinedVariable = 'warning',
          reportMissingImports = 'warning',
        },
      },
    },
  },
  on_init = function(client)
    client.settings.python = vim.tbl_deep_extend('force', client.settings.python or {}, { pythonPath = find_python(client.root_dir) })
    client:notify('workspace/didChangeConfiguration', { settings = nil })
  end,
})

-- Other file types. JSON and YAML files get autocomplete + validation from SchemaStore,
-- a catalog of known file formats (package.json, tsconfig.json, docker-compose.yml, GitHub Actions, ...).
vim.pack.add { 'https://github.com/b0o/SchemaStore.nvim' }

vim.lsp.config('jsonls', {
  settings = {
    json = { schemas = require('schemastore').json.schemas(), validate = { enable = true } },
  },
})
vim.lsp.config('yamlls', {
  settings = {
    yaml = { schemaStore = { enable = false, url = '' }, schemas = require('schemastore').yaml.schemas() },
  },
})

-- Recognise docker-compose files (so the docker-compose server attaches) but keep YAML highlighting.
vim.filetype.add {
  pattern = {
    ['.*/docker%-compose[^/]*%.ya?ml'] = 'yaml.docker-compose',
    ['.*/compose[^/]*%.ya?ml'] = 'yaml.docker-compose',
  },
}
vim.treesitter.language.register('yaml', 'yaml.docker-compose')

vim.lsp.enable {
  'basedpyright',
  'ts_ls',
  'eslint',
  'tailwindcss',
  'jsonls',
  'yamlls',
  'docker_compose_language_service',
  'dockerls',
  'html',
  'cssls',
  'sqlls',
}

-- Java / Spring Boot: uses nvim-jdtls, which handles Java better than the generic setup
-- (Maven/Gradle projects, debugging, organize imports).
vim.pack.add { 'https://github.com/mfussenegger/nvim-jdtls' }

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('snacks-java', { clear = true }),
  pattern = 'java',
  callback = function(args)
    local root = vim.fs.root(args.buf, { 'mvnw', 'gradlew', 'pom.xml', 'build.gradle', 'build.gradle.kts', '.git' })
    if not root or vim.fn.executable(mason_bin .. '/jdtls') == 0 then return end

    local debug_bundles = vim.fn.glob(vim.fn.stdpath 'data' .. '/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar', true, true)
    local blink_ok, blink = pcall(require, 'blink.cmp')

    require('jdtls').start_or_attach {
      cmd = { mason_bin .. '/jdtls', '-data', vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. root:gsub('/', '_') },
      root_dir = root,
      capabilities = blink_ok and blink.get_lsp_capabilities() or nil,
      init_options = { bundles = debug_bundles },
      on_attach = function() require('jdtls').setup_dap { hotcodereplace = 'auto' } end,
    }
  end,
})

-- ============================================================
-- [[ Organize imports: Alt+Shift+O (or Space o) ]]
-- Adds missing imports, removes unused ones and sorts them, like VS Code.
--   Python: basedpyright adds missing imports, ruff removes unused + sorts
--   JS/TS:  the TypeScript server does all three
--   Java:   jdtls does all three (asks you to pick if a name is ambiguous, e.g. two "List" classes)
-- ============================================================

-- Run one code action from a language server: apply its edit and/or run its command.
local function run_code_action(client, buf, action)
  if not action.edit and not action.command and client:supports_method('codeAction/resolve', buf) then
    local resolved = client:request_sync('codeAction/resolve', action, 5000, buf)
    action = resolved and resolved.result or action
  end
  if action.edit then vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding) end
  local command = type(action.command) == 'table' and action.command or (type(action.command) == 'string' and action) or nil
  if command then client:request_sync('workspace/executeCommand', command, 5000, buf) end
end

-- Ask a language server for whole-file actions of one kind (e.g. 'source.organizeImports') and apply them.
local function run_source_action(client, buf, kind)
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    range = { start = { line = 0, character = 0 }, ['end'] = { line = vim.api.nvim_buf_line_count(buf), character = 0 } },
    context = { only = { kind }, diagnostics = {} },
  }
  local res = client:request_sync('textDocument/codeAction', params, 5000, buf)
  for _, action in ipairs(res and res.result or {}) do
    run_code_action(client, buf, action)
  end
end

-- Python: for every '"X" is not defined', apply basedpyright's first "import X" / "from y import X" fix.
-- Fixes are applied one at a time, waiting for basedpyright to re-check the file in between,
-- because each added import moves the rest of the file down.
local function undefined_names(buf)
  local list = {}
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    local name = d.message:match '^"(.-)" is not defined'
    if name and d.user_data and d.user_data.lsp then table.insert(list, { name = name, diag = d.user_data.lsp }) end
  end
  return list
end

local function python_add_missing_imports(client, buf)
  local tried = {}
  for _ = 1, 50 do
    local target
    for _, item in ipairs(undefined_names(buf)) do
      if not tried[item.name] then
        target = item
        break
      end
    end
    if not target then return end
    tried[target.name] = true

    local res = client:request_sync('textDocument/codeAction', {
      textDocument = { uri = vim.uri_from_bufnr(buf) },
      range = target.diag.range,
      context = { only = { 'quickfix' }, diagnostics = { target.diag } },
    }, 5000, buf)
    for _, action in ipairs(res and res.result or {}) do
      if action.title:match '^import ' or action.title:match '^from ' then
        run_code_action(client, buf, action)
        vim.wait(5000, function()
          for _, item in ipairs(undefined_names(buf)) do
            if item.name == target.name then return false end
          end
          return true
        end, 50)
        break
      end
    end
  end
end

local function organize_imports()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype

  if ft == 'java' then
    require('jdtls').organize_imports()
    return
  end

  if ft == 'python' then
    local client = vim.lsp.get_clients({ bufnr = buf, name = 'basedpyright' })[1]
    if client then python_add_missing_imports(client, buf) end
    require('conform').format { bufnr = buf, formatters = { 'ruff_imports' }, timeout_ms = 3000 }
    return
  end

  local ts = vim.lsp.get_clients({ bufnr = buf, name = 'ts_ls' })[1]
  if ts then
    run_source_action(ts, buf, 'source.addMissingImports.ts')
    run_source_action(ts, buf, 'source.organizeImports.ts')
    return
  end

  vim.notify('Organize imports is not available for this file type', vim.log.levels.WARN)
end

map({ 'n', 'i' }, '<M-O>', organize_imports, { desc = 'Organize imports' })
map('n', '<leader>o', organize_imports, { desc = '[O]rganize imports' })

-- ============================================================
-- [[ Editing helpers ]]
-- ============================================================
require 'kickstart.plugins.autopairs' -- typing ( adds ), " adds ", etc.
require 'kickstart.plugins.indent_line' -- faint vertical lines showing indentation

-- ============================================================
-- [[ File sidebar (neo-tree) ]]
-- Press \ to open it (jumps to the current file), \ again to close it.
-- Click the "Files" / "Git" tabs at the top (or press < and >) to switch views.
-- The Git view lists only the files you've changed. Press H to show/hide hidden files.
-- ============================================================
vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

map('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

require('neo-tree').setup {
  sources = { 'filesystem', 'git_status' },
  source_selector = {
    winbar = true, -- the Files / Git tabs at the top of the sidebar
    sources = {
      { source = 'filesystem', display_name = ' Files ' },
      { source = 'git_status', display_name = ' Git ' },
    },
  },
  window = {
    width = 28, -- sidebar width (smaller number = thinner sidebar)
  },
  filesystem = {
    follow_current_file = { enabled = true }, -- highlight the file you're editing
    use_libuv_file_watcher = true, -- new/deleted files show up without refreshing
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
  git_status = {
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
}

-- ============================================================
-- [[ Terminal ]]
-- Ctrl+` (or Space t t) opens a terminal at the bottom; press it again to hide it.
-- The terminal keeps running while hidden (e.g. your dev server).
-- Inside the terminal, press Esc twice to scroll / move around like a normal buffer.
-- ============================================================
local term = { buf = nil, win = nil }

local function toggle_terminal()
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_win_hide(term.win)
    term.win = nil
    return
  end
  vim.cmd 'botright split'
  vim.api.nvim_win_set_height(0, 15)
  local job = term.buf and vim.api.nvim_buf_is_valid(term.buf) and vim.b[term.buf].terminal_job_id
  if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
    vim.api.nvim_win_set_buf(0, term.buf) -- terminal still running: show it again
  else
    vim.cmd.terminal()
    term.buf = vim.api.nvim_get_current_buf()
    vim.bo[term.buf].buflisted = false
  end
  term.win = vim.api.nvim_get_current_win()
  vim.cmd.startinsert()
end

map({ 'n', 't' }, '<C-`>', toggle_terminal, { desc = 'Toggle terminal' })
map('n', '<leader>tt', toggle_terminal, { desc = '[T]oggle [T]erminal' })

-- ============================================================
-- [[ Debugging ]]
-- Works for Python (incl. Django), Node.js / Next.js and Java / Spring Boot.
-- Set a breakpoint (F9), press F5 and choose what to run.
-- Next.js: start the dev server with  NODE_OPTIONS='--inspect' npm run dev
--          then F5 -> "Attach to Node.js".
-- ============================================================
vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}

local dap = require 'dap'
local dapui = require 'dapui'

map('n', '<F5>', dap.continue, { desc = 'Debug: Start/Continue' })
map('n', '<S-F5>', dap.terminate, { desc = 'Debug: Stop' })
map('n', '<F9>', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
map('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
map('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
map('n', '<S-F11>', dap.step_out, { desc = 'Debug: Step Out' })
map('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle [B]reakpoint' })
map('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Debug: Conditional [B]reakpoint' })
map('n', '<F7>', dapui.toggle, { desc = 'Debug: Show/hide debug panels' })

---@diagnostic disable-next-line: missing-fields
dapui.setup {}
dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError' })
vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DiagnosticWarn' })
vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticOk', linehl = 'Visual' })

-- Python debug adapter (Java's comes from nvim-jdtls above, JavaScript's is set up below)
require('mason-nvim-dap').setup {
  ensure_installed = { 'python' },
  handlers = {},
}

-- JavaScript / TypeScript (Node.js, Next.js)
dap.adapters['pwa-node'] = {
  type = 'server',
  host = 'localhost',
  port = '${port}',
  executable = { command = mason_bin .. '/js-debug-adapter', args = { '${port}' } },
}
for _, ft in ipairs { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' } do
  dap.configurations[ft] = {
    {
      type = 'pwa-node',
      request = 'launch',
      name = 'Node.js: run this file',
      program = '${file}',
      cwd = '${workspaceFolder}',
    },
    {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach to Node.js (pick a running process, e.g. your Next.js dev server)',
      processId = function() return require('dap.utils').pick_process() end,
      cwd = '${workspaceFolder}',
      sourceMaps = true,
    },
  }
end

-- Python: always debug with the project's interpreter, and add a Django option
local function python_path() return find_python(vim.fn.getcwd()) end
dap.configurations.python = dap.configurations.python or {}
for _, config in ipairs(dap.configurations.python) do
  config.pythonPath = python_path
end
table.insert(dap.configurations.python, 1, {
  type = 'python',
  request = 'launch',
  name = 'Django: runserver',
  program = '${workspaceFolder}/manage.py',
  args = { 'runserver', '--noreload' },
  django = true,
  justMyCode = true,
  pythonPath = python_path,
})

-- ============================================================
-- [[ Group names for the Space-key popup menu ]]
-- ============================================================
require('which-key').add {
  { '<leader>g', group = '[G]it' },
  { '<leader>r', group = '[R]un tests' },
  { '<leader>R', group = '[R]equests (API testing)' },
}

-- ============================================================
-- [[ Kitty integration ]]
-- Tells kitty "Neovim is running here", so kitty lets Ctrl+Tab, Ctrl+Shift+F etc.
-- through to Neovim instead of using them itself (see ~/.config/kitty/kitty.conf).
-- ============================================================
local kitty_group = vim.api.nvim_create_augroup('snacks-kitty', { clear = true })
vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, {
  group = kitty_group,
  callback = function() io.stdout:write '\x1b]1337;SetUserVar=in_editor=MQo\007' end,
})
vim.api.nvim_create_autocmd({ 'VimLeave', 'VimSuspend' }, {
  group = kitty_group,
  callback = function() io.stdout:write '\x1b]1337;SetUserVar=in_editor\007' end,
})

-- ============================================================
-- [[ Find files / search text (VS Code shortcuts) ]]
-- Uses kickstart's Telescope. Shows dotfiles like .env too, but not .git internals
-- or anything in .gitignore (node_modules, .venv, ...).
-- ============================================================
local telescope = require 'telescope.builtin'
local function find_files() telescope.find_files { find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.git/*' } } end
map('n', '<C-p>', find_files, { desc = 'Find file' })
map('n', '<leader>sf', find_files, { desc = '[S]earch [F]iles' })
map('n', '<C-S-f>', telescope.live_grep, { desc = 'Search text in project' })

-- ============================================================
-- [[ Tabs for open files ]]
-- ============================================================
vim.pack.add { { src = 'https://github.com/akinsho/bufferline.nvim', version = vim.version.range '*' } }

require('mini.bufremove').setup()
local function close_buffer(buf) require('mini.bufremove').delete(buf or 0, false) end

require('bufferline').setup {
  options = {
    close_command = close_buffer,
    right_mouse_command = close_buffer,
    diagnostics = 'nvim_lsp', -- show error/warning counts on tabs
    offsets = { { filetype = 'neo-tree', text = 'Files', separator = true } },
  },
}

map('n', '<C-Tab>', '<Cmd>BufferLineCycleNext<CR>', { desc = 'Next tab' })
map('n', '<C-S-Tab>', '<Cmd>BufferLineCyclePrev<CR>', { desc = 'Previous tab' })
map('n', '<S-l>', '<Cmd>BufferLineCycleNext<CR>', { desc = 'Next tab' })
map('n', '<S-h>', '<Cmd>BufferLineCyclePrev<CR>', { desc = 'Previous tab' })
map('n', '<leader>x', function() close_buffer() end, { desc = 'Close tab' })

-- ============================================================
-- [[ Problems panel ]]
-- ============================================================
vim.pack.add { 'https://github.com/folke/trouble.nvim' }
require('trouble').setup {}
map('n', '<C-S-m>', '<Cmd>Trouble diagnostics toggle<CR>', { desc = 'Problems panel' })
map('n', '<leader>p', '<Cmd>Trouble diagnostics toggle<CR>', { desc = '[P]roblems panel' })

-- ============================================================
-- [[ Sticky header ]]
-- Keeps the current function/class name pinned at the top while you scroll.
-- ============================================================
vim.pack.add { 'https://github.com/nvim-treesitter/nvim-treesitter-context' }
require('treesitter-context').setup { max_lines = 3 }

-- ============================================================
-- [[ lazygit ]]
-- Space g g opens lazygit in a floating window. Press q to close it.
-- Pressing e on a file in lazygit opens it here (set up in ~/.config/lazygit/config.yml).
-- ============================================================
local function float_terminal(cmd)
  local buf = vim.api.nvim_create_buf(false, true)
  local width, height = math.floor(vim.o.columns * 0.9), math.floor(vim.o.lines * 0.9)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  })
  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        vim.cmd 'silent! checktime' -- reload files that git changed (e.g. after a pull or checkout)
      end)
    end,
  })
  vim.cmd.startinsert()
end

map('n', '<leader>gg', function() float_terminal { 'lazygit' } end, { desc = 'lazy[G]it' })

-- ============================================================
-- [[ Database viewer ]]
-- Space D opens it. Press A to add a connection, e.g.
--   postgresql://user:password@localhost:5432/mydb
--   sqlite:/full/path/to/db.sqlite3          (needs the sqlite3 program installed)
-- Write a query, then press Space S to run it.
-- ============================================================
vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_execute_on_save = 0 -- don't run queries on save (files auto-save!)
vim.pack.add {
  'https://github.com/tpope/vim-dadbod',
  'https://github.com/kristijanhusak/vim-dadbod-ui',
  'https://github.com/kristijanhusak/vim-dadbod-completion',
}
map('n', '<leader>D', '<Cmd>DBUIToggle<CR>', { desc = '[D]atabase viewer' })

-- Table/column autocomplete in SQL files
local blink_config_ok, blink_config = pcall(require, 'blink.cmp.config')
if blink_config_ok then
  blink_config.sources.providers.dadbod = { name = 'Dadbod', module = 'vim_dadbod_completion.blink' }
  for _, ft in ipairs { 'sql', 'mysql', 'plsql' } do
    blink_config.sources.per_filetype[ft] = { 'dadbod', 'snippets', 'buffer' }
  end
end

-- ============================================================
-- [[ API testing: .http files ]]
-- Write requests in a file ending in .http, put the cursor on one and press Enter.
-- The response opens on the right. Separate requests with ###.
--
--   @base = http://localhost:8000
--
--   ### Login
--   POST {{base}}/api/auth/login/
--   Content-Type: application/json
--
--   { "email": "me@example.com", "password": "{{TEST_PASSWORD}}" }
--
--   ###
--   GET {{base}}/api/orders/
--   Authorization: Bearer {{TOKEN}}
--
-- {{NAME}} is filled from: @NAME = ... lines in the file, then the project's .env file,
-- then your shell's environment variables.
-- ============================================================
local function read_dotenv(start_dir)
  local vars = {}
  local path = vim.fs.find('.env', { upward = true, path = start_dir, stop = vim.env.HOME })[1]
  if not path then return vars end
  for _, line in ipairs(vim.fn.readfile(path)) do
    local key, value = line:match '^%s*export%s+([%w_]+)%s*=%s*(.-)%s*$'
    if not key then
      key, value = line:match '^%s*([%w_]+)%s*=%s*(.-)%s*$'
    end
    if key then vars[key] = (value:gsub('^"(.*)"$', '%1'):gsub("^'(.*)'$", '%1')) end
  end
  return vars
end

local function send_http_request()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]

  -- variables: @name = value anywhere in the file
  local file_vars = {}
  for _, line in ipairs(lines) do
    local key, value = line:match '^%s*@([%w_%-]+)%s*=%s*(.-)%s*$'
    if key then file_vars[key] = value end
  end
  local dotenv = read_dotenv(vim.fn.expand '%:p:h')
  local missing = {}
  local function fill(text)
    return (text:gsub('{{%s*([%w_%-]+)%s*}}', function(name)
      local value = file_vars[name] or dotenv[name] or vim.env[name]
      if not value then table.insert(missing, name) end
      return value or ''
    end))
  end

  -- find the request block around the cursor (blocks are separated by ###)
  local first, last = 1, #lines
  for i = cursor, 1, -1 do
    if lines[i]:match '^###' then
      first = i + 1
      break
    end
  end
  for i = cursor + 1, #lines do
    if lines[i]:match '^###' then
      last = i - 1
      break
    end
  end

  local method, url, headers, body_lines = nil, nil, {}, {}
  local stage = 'request'
  for i = first, last do
    local line = lines[i]
    if stage == 'request' then
      if not (line:match '^%s*$' or line:match '^%s*#' or line:match '^%s*//' or line:match '^%s*@') then
        method, url = line:match '^%s*(%u+)%s+(%S+)'
        if not method then
          method, url = 'GET', line:match '^%s*(%S+)'
        end
        stage = 'headers'
      end
    elseif stage == 'headers' then
      if line:match '^%s*$' then
        stage = 'body'
      elseif not line:match '^%s*#' then
        table.insert(headers, line)
      end
    else
      table.insert(body_lines, line)
    end
  end
  if not url then return vim.notify('No request found under the cursor', vim.log.levels.WARN) end
  while #body_lines > 0 and body_lines[#body_lines]:match '^%s*$' do
    table.remove(body_lines)
  end

  local args = { 'curl', '-sS', '-i', '-X', method, fill(url) }
  for _, header in ipairs(headers) do
    vim.list_extend(args, { '-H', fill(header) })
  end
  local body = #body_lines > 0 and fill(table.concat(body_lines, '\n')) or nil
  if body then vim.list_extend(args, { '--data-binary', '@-' }) end
  if #missing > 0 then vim.notify('Not set: ' .. table.concat(missing, ', '), vim.log.levels.WARN) end

  local started = vim.uv.hrtime()
  vim.notify(method .. ' ' .. fill(url))
  vim.system(args, { stdin = body, text = true }, function(result)
    vim.schedule(function()
      local ms = math.floor((vim.uv.hrtime() - started) / 1e6)
      local out = (result.stdout or ''):gsub('\r', '')
      local head, resp_body = out:match '^(.-)\n\n(.*)$'
      head, resp_body = head or out, resp_body or ''
      local is_json = head:lower():match 'content%-type:%s*[^\n]*json' ~= nil
      if is_json and vim.fn.executable 'jq' == 1 then
        local pretty = vim.fn.system({ 'jq', '.' }, resp_body)
        if vim.v.shell_error == 0 then resp_body = pretty end
      end

      local output = vim.split(head, '\n')
      output[1] = output[1] .. '   (' .. ms .. ' ms)'
      table.insert(output, '')
      vim.list_extend(output, vim.split(resp_body, '\n'))
      if result.code ~= 0 then output = vim.split('Request failed:\n' .. (result.stderr or ''), '\n') end

      -- show it in a reusable "Response" window on the right
      local resp_buf = vim.fn.bufnr 'HTTP Response'
      if resp_buf == -1 then
        resp_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(resp_buf, 'HTTP Response')
      end
      vim.bo[resp_buf].modifiable = true
      vim.api.nvim_buf_set_lines(resp_buf, 0, -1, false, output)
      vim.bo[resp_buf].modifiable = false
      vim.bo[resp_buf].filetype = is_json and 'json' or 'text'
      if vim.fn.bufwinid(resp_buf) == -1 then
        local current = vim.api.nvim_get_current_win()
        vim.cmd 'botright vsplit'
        vim.api.nvim_win_set_buf(0, resp_buf)
        vim.api.nvim_set_current_win(current)
      end
    end)
  end)
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('snacks-http', { clear = true }),
  pattern = 'http',
  callback = function(args)
    map('n', '<CR>', send_http_request, { buffer = args.buf, desc = 'Send request' })
    map('n', '<leader>Rs', send_http_request, { buffer = args.buf, desc = '[R]equest: [s]end' })
  end,
})

-- ============================================================
-- [[ Tests ]]
-- Python (pytest or Django's test runner, picked automatically), Jest, Vitest, JUnit.
-- Java needs a one-time download: run  :NeotestJava setup
-- ============================================================
vim.pack.add {
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/nvim-neotest/neotest-python',
  'https://github.com/nvim-neotest/neotest-jest',
  'https://github.com/marilari88/neotest-vitest',
  'https://github.com/rcasia/neotest-java',
}

local neotest = require 'neotest'

-- Django's test runner needs DJANGO_SETTINGS_MODULE. Look for it the way manage.py would:
-- already set in the environment, in the project's .env, or written in manage.py.
local function django_settings_module(root)
  if vim.env.DJANGO_SETTINGS_MODULE then return vim.env.DJANGO_SETTINGS_MODULE end
  if not vim.uv.fs_stat(root .. '/manage.py') then return nil end
  local from_env = read_dotenv(root).DJANGO_SETTINGS_MODULE
  if from_env and from_env ~= '' then return from_env end
  for _, line in ipairs(vim.fn.readfile(root .. '/manage.py')) do
    local module = line:match 'DJANGO_SETTINGS_MODULE[\'"]%s*,%s*[\'"]([%w_%.]+)[\'"]'
    if module then return module end
  end
end

local python_tests = require 'neotest-python' {
  python = function(root)
    local settings = django_settings_module(root)
    if settings then return { 'env', 'DJANGO_SETTINGS_MODULE=' .. settings, find_python(root) } end
    return { find_python(root) }
  end,
  -- test_*.py, *_test.py, and Django's tests.py / tests/ folders
  is_test_file = function(path)
    local name = vim.fs.basename(path)
    if not name:match '%.py$' then return false end
    return name:match '^test_' ~= nil or name:match '_test%.py$' ~= nil or name == 'tests.py' or path:match '/tests/[^/]+%.py$' ~= nil
  end,
}
-- Also treat Django projects (manage.py) and plain requirements.txt projects as Python projects
local python_root = python_tests.root
python_tests.root = function(dir)
  return python_root(dir) or vim.fs.root(dir, { 'manage.py', 'requirements.txt' })
end

neotest.setup {
  adapters = {
    python_tests,
    require 'neotest-jest' {},
    require 'neotest-vitest' {},
    require 'neotest-java' {},
  },
}

map('n', '<leader>rt', function() neotest.run.run() end, { desc = '[R]un nearest [T]est' })
map('n', '<leader>rf', function() neotest.run.run(vim.fn.expand '%') end, { desc = '[R]un tests in [F]ile' })
map('n', '<leader>ra', function() neotest.run.run(vim.fn.getcwd()) end, { desc = '[R]un [A]ll tests' })
map('n', '<leader>rd', function() neotest.run.run { strategy = 'dap' } end, { desc = '[R]un nearest test in [D]ebugger' })
map('n', '<leader>rs', function() neotest.summary.toggle() end, { desc = '[R]un: test [S]ummary panel' })
map('n', '<leader>ro', function() neotest.output_panel.toggle() end, { desc = '[R]un: test [O]utput' })

-- ============================================================
-- [[ AI autocomplete (GitHub Copilot) ]]
-- Grey "ghost text" suggestions as you type. Tab accepts, Alt+] / Alt+[ cycles, Ctrl+] dismisses.
-- One-time setup: run  :Copilot auth  and sign in with GitHub (Copilot Free works).
-- ============================================================
vim.pack.add { 'https://github.com/zbirenbaum/copilot.lua' }
require('copilot').setup {
  panel = { enabled = false },
  suggestion = {
    auto_trigger = true,
    keymap = { accept = '<Tab>', accept_word = '<M-Right>', next = '<M-]>', prev = '<M-[>', dismiss = '<C-]>' },
  },
}

-- ============================================================
-- [[ Reopen where you left off ]]
-- Running `nvim` or `nvim .` in a project reopens the files you had open last time.
-- Opening a specific file (`nvim app.py`) doesn't touch the saved session.
-- ============================================================
vim.pack.add { 'https://github.com/folke/persistence.nvim' }
vim.o.sessionoptions = 'buffers,curdir,folds,tabpages,winsize'
local persistence = require 'persistence'
persistence.setup {}

local session_group = vim.api.nvim_create_augroup('snacks-session', { clear = true })

-- Before saving: close sidebars/panels so they aren't saved as empty windows.
vim.api.nvim_create_autocmd('User', {
  group = session_group,
  pattern = 'PersistenceSavePre',
  callback = function()
    pcall(vim.cmd, 'Neotree close')
    pcall(function() require('dapui').close() end)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype ~= '' and #vim.api.nvim_list_wins() > 1 then pcall(vim.api.nvim_win_close, win, true) end
    end
  end,
})

vim.api.nvim_create_autocmd('VimEnter', {
  group = session_group,
  nested = true, -- so restored files get their language servers, highlighting, etc.
  callback = function()
    local argv = vim.fn.argv()
    local dir
    if #argv == 0 then
      dir = vim.fn.getcwd()
    elseif #argv == 1 and vim.fn.isdirectory(argv[1]) == 1 then
      dir = vim.fn.fnamemodify(argv[1], ':p')
    else
      persistence.stop() -- opened specific files: leave the project's session alone
      return
    end
    if vim.g.snacks_stdin then return end
    vim.fn.chdir(dir)

    local file = persistence.current()
    if vim.fn.filereadable(file) == 0 then file = persistence.current { branch = false } end
    if vim.fn.filereadable(file) == 0 then return end

    pcall(vim.cmd, 'Neotree close')
    persistence.load()
    -- remove the folder buffer left over from `nvim .`
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' and vim.fn.isdirectory(name) == 1 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    end
    vim.schedule(function()
      pcall(vim.cmd, 'Neotree show')
      -- put the cursor back in the file, not the sidebar
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' and vim.api.nvim_win_get_config(win).relative == '' then
          vim.api.nvim_set_current_win(win)
          break
        end
      end
    end)
  end,
})
vim.api.nvim_create_autocmd('StdinReadPre', { group = session_group, callback = function() vim.g.snacks_stdin = true end })
