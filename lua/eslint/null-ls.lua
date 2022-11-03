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

  local bin = options.get("bin") --[[@as string]]

  local command = utils.resolve_bin(bin)

  if not command then
    return
  end

  local function make_eslint_opts(handler, method)
    local opts = {
      args = utils.get_cli_args(bin, method),
      command = command,
      on_output = handler,
      to_stdin = true,
    }

    if method == null_ls.methods.CODE_ACTION then
      opts.check_exit_code = { 0, 1 }
      opts.format = "json_raw"
      opts.use_cache = true
    elseif method == null_ls.methods.DIAGNOSTICS or method == null_ls.methods.DIAGNOSTICS_ON_SAVE then
      opts.check_exit_code = function(code)
        return code <= 1
      end
      opts.format = "json_raw"
      opts.use_cache = true
    elseif method == null_ls.methods.FORMATTING then
      if bin == "eslint" then
        opts.check_exit_code = { 0, 1 }
        opts.format = "json"
      else
        opts.ignore_stderr = true
      end
    end

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

  if options.get("code_actions.apply_on_save.enable") then
    local method = null_ls.methods.FORMATTING

    local generator = null_ls.generator(make_eslint_opts(utils.formatting_handler[bin], method))
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
