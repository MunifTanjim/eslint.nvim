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
    format = "json_raw",
    to_stdin = true,
    check_exit_code = function(code)
      return code <= 1
    end,
    use_cache = true,
  }

  local function make_eslint_opts(handler, method)
    local opts = vim.deepcopy(eslint_opts)
    opts.args = utils.get_cli_args(eslint_bin, method)
    opts.on_output = handler
    return opts
  end

  if options.get("code_actions.enable") then
    local method = null_ls.methods.CODE_ACTION
    local generator = null_ls.generator(make_eslint_opts(utils.code_action_handler, method))
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

    local generator = null_ls.generator(make_eslint_opts(utils.diagnostic_handler, method))
    null_ls.register({
      filetypes = utils.supported_filetypes,
      name = name,
      method = method,
      generator = generator,
    })
  end
end

return M
