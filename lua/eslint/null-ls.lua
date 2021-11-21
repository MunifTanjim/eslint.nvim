local ok, null_ls = pcall(require, "null-ls")

local options = require("eslint.options")
local utils = require("eslint.utils")

local function eslint_enabled()
  return utils.config_file_exists()
end

local M = {}

function M.setup()
  if not ok then
    return
  end

  local name = "eslint"

  if null_ls.is_registered(name) then
    return
  end

  if not eslint_enabled() then
    return
  end

  local eslint_bin = options.get("bin")

  local command = utils.resolve_bin(eslint_bin)

  if not command then
    return
  end

  local eslint_opts = {
    command = command,
    args = options.get("args"),
    format = "json_raw",
    to_stdin = true,
    check_exit_code = function(code)
      return code <= 1
    end,
    use_cache = true,
  }

  local function make_eslint_opts(handler)
    local opts = vim.deepcopy(eslint_opts)
    opts.on_output = handler
    return opts
  end

  if options.get("code_actions.enable") then
    local method = null_ls.methods.CODE_ACTION
    local generator = null_ls.generator(make_eslint_opts(utils.code_action_handler))
    null_ls.register({
      filetypes = utils.supported_filetypes,
      name = name,
      method = method,
      generator = generator,
    })
  end

  if options.get("code_actions.apply_on_save.enable") then
    local method = null_ls.methods.FORMATTING
    local opts = vim.deepcopy(eslint_opts)
    opts.command = function(params)
      local bufnr = params.bufnr
      local diagnostics = vim.diagnostic.get(bufnr, {
        severity = vim.diagnostic.severity.ERROR,
      })
      print(vim.inspect(diagnostics))
      local actions = vim.lsp.buf.code_action({
        diagnostics = diagnostics,
      })
      print(vim.inspect(actions))
    end
    opts.args = {}
    opts.on_output = function(params, done)
      print("on_output", vim.inspect(params))

      local output = params.output

      if not output then
        return done()
      end

      done({})
    end
    local generator = null_ls.generator(opts)
    null_ls.register({
      filetypes = utils.supported_filetypes,
      name = name,
      method = method,
      generator = generator,
    })
  end

  if options.get("diagnostics.enable") then
    local method = null_ls.methods.DIAGNOSTICS
    if options.get("diagnostics.run_on") == "save" then
      method = null_ls.methods.DIAGNOSTICS_ON_SAVE
    end

    local generator = null_ls.generator(make_eslint_opts(utils.diagnostic_handler))
    null_ls.register({
      filetypes = utils.supported_filetypes,
      name = name,
      method = method,
      generator = generator,
    })
  end
end

return M
