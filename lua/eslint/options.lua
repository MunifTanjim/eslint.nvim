local function tbl_flatten(tbl, result, prefix, depth)
  result = result or {}
  prefix = prefix or ""
  depth = type(depth) == "number" and depth or 1
  for k, v in pairs(tbl) do
    if type(v) == "table" and not vim.tbl_islist(v) and depth < 42 then
      tbl_flatten(v, result, prefix .. k .. ".", depth + 1)
    else
      result[prefix .. k] = v
    end
  end
  return result
end

local bins = { "eslint", "eslint_d" }
local apply_on_save_types = { "directive", "problem", "suggestion", "layout" }
local disable_rule_comment_locations = { "same_line", "separate_line" }
local run_ons = { "save", "type" }

local default_options = {
  _initialized = false,
  bin = "eslint",
  code_actions = {
    enable = true,
    apply_on_save = {
      enable = true,
      types = {},
    },
    disable_rule_comment = {
      enable = true,
      location = "separate_line",
    },
  },
  diagnostics = {
    enable = true,
    report_unused_disable_directives = false,
    run_on = "type",
  },
}

local function get_validate_argmap(tbl, key)
  local argmap = {
    ["bin"] = {
      tbl["bin"],
      function(val)
        return val == nil or vim.tbl_contains(bins, val)
      end,
      table.concat(bins, ", "),
    },
    ["code_actions.enable"] = {
      tbl["code_actions.enable"],
      "boolean",
      true,
    },
    ["code_actions.apply_on_save.enable"] = {
      tbl["code_actions.apply_on_save.enable"],
      "boolean",
      true,
    },
    ["code_actions.apply_on_save.types"] = {
      tbl["code_actions.apply_on_save.types"],
      function(val)
        if val == nil then
          return true
        end

        if type(val) ~= "table" then
          return false, "invalid type: " .. type(val)
        end

        for _, t in ipairs(val) do
          if not vim.tbl_contains(apply_on_save_types, t) then
            return false, "invalid value: " .. t
          end
        end

        return true
      end,
      "table containing " .. table.concat(apply_on_save_types, ", "),
    },
    ["code_actions.disable_rule_comment.enable"] = {
      tbl["code_actions.disable_rule_comment.enable"],
      "boolean",
      true,
    },
    ["code_actions.disable_rule_comment.location"] = {
      tbl["code_actions.disable_rule_comment.location"],
      function(val)
        return val == nil or vim.tbl_contains(disable_rule_comment_locations, val)
      end,
      table.concat(disable_rule_comment_locations, ", "),
    },
    ["diagnostics.enable"] = {
      tbl["diagnostics.enable"],
      "boolean",
      true,
    },
    ["diagnostics.report_unused_disable_directives"] = {
      tbl["diagnostics.report_unused_disable_directives"],
      "boolean",
      true,
    },
    ["diagnostics.run_on"] = {
      tbl["diagnostics.run_on"],
      function(val)
        return val == nil or vim.tbl_contains(run_ons, val)
      end,
      table.concat(run_ons, ", "),
    },
  }

  if type(key) == "string" then
    return {
      [key] = argmap[key],
    }
  end

  return argmap
end

local function validate_options(user_options)
  vim.validate(get_validate_argmap(user_options))
end

local options = vim.deepcopy(tbl_flatten(default_options))

local M = {}

function M.setup(user_options)
  if options._initialized then
    return
  end

  user_options = tbl_flatten(user_options or {})

  validate_options(user_options)

  options = vim.tbl_deep_extend("force", options, user_options)

  options._initialized = true
end

function M.get(key)
  if type(key) == "string" then
    return vim.deepcopy(options[key])
  end

  return vim.deepcopy(options)
end

function M.set(key, value)
  local is_internal = vim.startswith(key, "_")

  local argmap = get_validate_argmap({ [key] = value }, key)

  if not is_internal and argmap[key] == nil then
    return error(string.format("invalid key: %s", key))
  end

  vim.validate(argmap)

  options[key] = vim.deepcopy(value)
end

function M.reset()
  options = vim.deepcopy(default_options)
end

return M
