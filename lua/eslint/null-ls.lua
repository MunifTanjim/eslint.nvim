local ok, null_ls = pcall(require, "null-ls")

local options = require("eslint.options")
local utils = require("eslint.utils")

local function get_on_output_fn(callback, is_diagnostics)
  return function(params)
    local output, err = params.output, params.err

    if err and is_diagnostics then
      return callback(params)
    end

    if not (output and output[1] and output[1].messages) then
      return
    end

    params.messages = output[1].messages

    return callback(params)
  end
end

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

  local function make_eslint_opts(handler, is_diagnostics)
    local opts = vim.deepcopy(eslint_opts)
    opts.on_output = get_on_output_fn(handler, is_diagnostics)
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

  if options.get("diagnostics.enable") then
    local method = null_ls.methods.DIAGNOSTICS
    if options.get("diagnostics.run_on") == "save" then
      method = null_ls.methods.DIAGNOSTICS_ON_SAVE
    end

    local generator = null_ls.generator(make_eslint_opts(utils.diagnostic_handler, true))
    null_ls.register({
      filetypes = utils.supported_filetypes,
      name = name,
      method = method,
      generator = generator,
    })
  end
end

return M
