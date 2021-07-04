local find_git_ancestor = require("lspconfig.util").find_git_ancestor
local find_package_json_ancestor = require("lspconfig.util").find_package_json_ancestor
local is_file = require("lspconfig.util").path.is_file
local options = require("eslint.options")

local M = {}

local function get_col(line_len, line_offset, offset)
  for i = 0, line_len do
    local char_offset = line_offset + i
    if char_offset == offset then
      return i
    end
  end
end

local function convert_offset(row, params, start_offset, end_offset)
  local start_line_offset = vim.api.nvim_buf_get_offset(params.bufnr, row)
  local start_line_len = #params.content[row + 1]

  local end_line_offset, end_row = start_line_offset, row
  while end_line_offset + #params.content[end_row + 1] < end_offset do
    end_row = end_row + 1
    end_line_offset = vim.api.nvim_buf_get_offset(params.bufnr, end_row)
  end
  local end_line_len = #params.content[end_row + 1]

  local start_col = get_col(start_line_len, start_line_offset, start_offset)
  local end_col = get_col(end_line_len, end_line_offset, end_offset)
  return start_col, end_col, end_row
end

local function is_fixable(problem, row)
  if not problem or not problem.line then
    return false
  end

  if problem.endLine ~= nil then
    return problem.line - 1 <= row and problem.endLine - 1 >= row
  end
  if problem.fix ~= nil then
    return problem.line - 1 == row
  end

  return false
end

local function get_message_range(problem)
  local row = problem.line and problem.line > 0 and problem.line - 1 or 0
  local col = problem.column and problem.column > 0 and problem.column - 1 or 0
  local end_row = problem.endLine and problem.endLine - 1 or 0
  local end_col = problem.endColumn and problem.endColumn - 1 or 0

  return { row = row, col = col, end_row = end_row, end_col = end_col }
end

local function get_fix_range(problem, params)
  local row = problem.line - 1
  local offset = problem.fix.range[1]
  local end_offset = problem.fix.range[2]
  local col, end_col, end_row = convert_offset(row, params, offset, end_offset)

  return { row = row, col = col, end_row = end_row, end_col = end_col }
end

local function generate_edit_action(title, new_text, range, params)
  return {
    title = string.format("[eslint] %s", title),
    action = function()
      vim.api.nvim_buf_set_text(params.bufnr, range.row, range.col, range.end_row, range.end_col, vim.split(new_text, "\n"))
    end,
  }
end

local function generate_edit_line_action(title, new_text, row, params)
  return {
    title = string.format("[eslint] %s", title),
    action = function()
      vim.api.nvim_buf_set_lines(params.bufnr, row, row, false, { new_text })
    end,
  }
end

local function generate_suggestion_action(suggestion, message, params)
  local title = suggestion.desc
  local new_text = suggestion.fix.text
  local range = get_message_range(message)

  return generate_edit_action(title, new_text, range, params)
end

local function generate_fix_action(message, params)
  local title = "Apply fix for " .. message.ruleId
  local new_text = message.fix.text
  local range = get_fix_range(message, params)

  return generate_edit_action(title, new_text, range, params)
end

local function generate_disable_actions(message, indentation, params)
  local rule_id = message.ruleId

  local actions = {}
  local line_title = "Disable " .. rule_id .. " for this line"
  local line_new_text = indentation .. "// eslint-disable-next-line " .. rule_id
  local row = message.line and message.line > 0 and message.line - 1 or 0
  table.insert(actions, generate_edit_line_action(line_title, line_new_text, row, params))

  local file_title = "Disable " .. rule_id .. " for the entire file"
  local file_new_text = "/* eslint-disable " .. rule_id .. " */"
  table.insert(actions, generate_edit_line_action(file_title, file_new_text, 0, params))

  return actions
end

function M.code_action_handler(params)
  local row = params.row
  local indentation = string.match(params.content[row], "^%s+")
  if not indentation then
    indentation = ""
  end

  local rules, actions = {}, {}
  for _, message in ipairs(params.messages) do
    if is_fixable(message, row - 1) then
      if message.suggestions then
        for _, suggestion in ipairs(message.suggestions) do
          table.insert(actions, generate_suggestion_action(suggestion, message, params))
        end
      end
      if message.fix then
        table.insert(actions, generate_fix_action(message, params))
      end
      if
        message.ruleId
        and options.get("enable_disable_comments")
        and not vim.tbl_contains(rules, message.ruleId)
      then
        table.insert(rules, message.ruleId)
        vim.list_extend(actions, generate_disable_actions(message, indentation, params))
      end
    end
  end
  return actions
end

-- eslint severity can be:
--   1: warning
--   2: error
-- lsp severity is the opposite
local lsp_severity_by_eslint_severity = {
  [1] = 2,
  [2] = 1,
}

local function create_diagnostic(message)
  local range = get_message_range(message)

  return {
    message = message.message,
    code = message.ruleId,
    row = range.row + 1,
    col = range.col,
    end_row = range.end_row + 1,
    end_col = range.end_col,
    severity = lsp_severity_by_eslint_severity[message.severity],
    source = "eslint",
  }
end

function M.diagnostic_handler(params)
  local diagnostics = {}
  if params.err then
    params.messages = { { message = params.err } }
  end

  for _, message in ipairs(params.messages) do
    table.insert(diagnostics, create_diagnostic(message))
  end

  return diagnostics
end

local function get_project_root()
  local startpath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  return find_git_ancestor(startpath) or find_package_json_ancestor(startpath)
end

local eslint_config_files = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.json",
  ".eslintrc.yml",
  ".eslintrc.yaml",
}

local config_files_by_bin = {
  eslint = eslint_config_files,
  eslint_d = eslint_config_files,
}

function M.config_file_exists(bin)
  local project_root = get_project_root()
  for _, config_file in pairs(config_files_by_bin[bin]) do
    if is_file(project_root .. "/" .. config_file) then
      return true
    end
  end

  return false
end

function M.resolve_bin(cmd)
  local project_root = get_project_root()
  local local_bin = project_root .. "/node_modules/.bin" .. "/" .. cmd
  if is_file(local_bin) then
    return local_bin
  else
    return cmd
  end
end

M.supported_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "javascript.jsx",
  "typescript.tsx",
}

return M
