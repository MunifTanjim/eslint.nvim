local ok, null_ls = pcall(require, "null-ls")

local options = require("eslint.options")
local utils = require("eslint.utils")

local function get_on_output_fn(callback, handle_errors)
  return function(params)
    local output, err = params.output, params.err

    if err and handle_errors then
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
  local bin = options.get("bin")
  return utils.config_file_exists(bin)
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

  local sources = {}

  local function add_source(method, generator)
    table.insert(sources, { method = method, generator = generator })
  end

  if eslint_enabled() then
    local eslint_bin = options.get("bin")

    local eslint_opts = {
      command = utils.resolve_bin(eslint_bin),
      args = options.get("args"),
      format = "json_raw",
      to_stdin = true,
      check_exit_code = function(code)
        return code <= 1
      end,
      use_cache = true,
    }

    local function make_eslint_opts(handler, method)
      local opts = vim.deepcopy(eslint_opts)
      opts.on_output = get_on_output_fn(handler, method == null_ls.methods.DIAGNOSTICS)
      return opts
    end

    if options.get("enable_code_actions") then
      local method = null_ls.methods.CODE_ACTION
      add_source(method, null_ls.generator(make_eslint_opts(utils.code_action_handler, method)))
    end

    if options.get("enable_diagnostics") then
      local method = null_ls.methods.DIAGNOSTICS
      add_source(method, null_ls.generator(make_eslint_opts(utils.diagnostic_handler, method)))
    end
  end

  if vim.tbl_count(sources) > 0 then
    null_ls.register({
      filetypes = utils.supported_filetypes,
      name = name,
      sources = sources,
    })
  end
end

return M
