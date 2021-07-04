local executables = { "eslint", "eslint_d" }
local eslint_args = { "-f", "json", "--stdin", "--stdin-filename", "$FILENAME" }
local args_by_bin = {
  eslint = eslint_args,
  eslint_d = eslint_args
}

local default_options = {
  _initialized = false,
  bin = "eslint",
  enable_code_actions = true,
  enable_diagnostics = true,
  enable_disable_comments = true,
}

local type_overrides = {
  bin = function(v)
    return not v or vim.tbl_contains(executables, v), table.concat(executables, ", ")
  end,
}

local function get_validate_args(name)
  if vim.startswith(name, "_") then
    return "nil", true
  end

  local override = type_overrides[name]

  if type(override) == "table" then
    return function(v)
      return vim.tbl_contains(override, type(v)), table.concat(override, ", ")
    end
  end

  if type(override) == "function" then
    return override
  end

  return type(default_options[name]), true
end

local options = vim.deepcopy(default_options)

local function validate_options(user_options)
  local to_validate = {}

  for k in pairs(default_options) do
    local arg_1, arg_2 = get_validate_args(k)
    to_validate[k] = { user_options[k], arg_1, arg_2 }
  end

  vim.validate(to_validate)
end

local M = {}

function M.setup(user_options)
  if options._initialized then
    return
  end

  validate_options(user_options)

  options = vim.tbl_extend("force", options, user_options)
  options.args = options.bin and args_by_bin[options.bin]

  options._initialized = true
end

function M.get(name)
  if type(name) == "string" then
    return vim.deepcopy(options[name])
  end

  return vim.deepcopy(options)
end

function M.reset()
  options = vim.deepcopy(default_options)
end

return M
