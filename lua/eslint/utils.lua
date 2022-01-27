local find_git_ancestor = require("lspconfig.util").find_git_ancestor
local find_package_json_ancestor = require("lspconfig.util").find_package_json_ancestor
local path_join = require("lspconfig.util").path.join
local options = require("eslint.options")

local function get_messages(output)
  if output and output[1] and output[1].messages then
    return output[1].messages
  end

  return {}
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
  local content = table.concat(params.content, "\n")

  local start_offset = vim.str_byteindex(content, problem.fix.range[1], true)
  local end_offset = vim.str_byteindex(content, problem.fix.range[2], true)

  local lines_from_start_to_start_offset = vim.fn.split(vim.fn.strpart(content, 0, start_offset), "\n")
  local lines_from_start_offset_to_end_offset = vim.fn.split(
    vim.fn.strpart(content, start_offset, end_offset - start_offset),
    "\n"
  )

  local start_row = #lines_from_start_to_start_offset - 1
  local end_row
  if start_offset == end_offset then
    end_row = start_row
  else
    end_row = start_row + #lines_from_start_offset_to_end_offset - 1
  end

  local start_col = #lines_from_start_to_start_offset[#lines_from_start_to_start_offset]
  local end_col
  if start_offset == end_offset then
    end_col = start_col
  else
    end_col = #lines_from_start_offset_to_end_offset[#lines_from_start_offset_to_end_offset]

    if start_row == end_row then
      end_col = start_col + end_col
    end
  end

  return { row = start_row, col = start_col, end_row = end_row, end_col = end_col }
end

local function generate_edit_action(title, new_text, range, params)
  return {
    title = string.format("[eslint] %s", title),
    action = function()
      vim.api.nvim_buf_set_text(
        params.bufnr,
        range.row,
        range.col,
        range.end_row,
        range.end_col,
        vim.split(new_text, "\n")
      )
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
  local preferred_location = options.get("code_actions.disable_rule_comment.location")
  local should_comment_on_same_line = preferred_location == "same_line" and message.line == message.endLine
  if should_comment_on_same_line then
    local line_new_text = " // eslint-disable-line " .. rule_id
    local row = message.endLine - 1
    local col = string.len(vim.api.nvim_buf_get_lines(params.bufnr, row, row + 1, true)[1])
    local range = { row = row, col = col, end_row = row, end_col = col }
    table.insert(actions, generate_edit_action(line_title, line_new_text, range, params))
  else
    local line_new_text = indentation .. "// eslint-disable-next-line " .. rule_id
    local row = message.line and message.line > 0 and message.line - 1 or 0
    table.insert(actions, generate_edit_line_action(line_title, line_new_text, row, params))
  end

  local file_title = "Disable " .. rule_id .. " for the entire file"
  local file_new_text = "/* eslint-disable " .. rule_id .. " */"
  table.insert(actions, generate_edit_line_action(file_title, file_new_text, 0, params))

  return actions
end

local M = {}

---@param bin string
---@param method string
---@return string[]
function M.get_cli_args(bin, method)
  local methods = require("null-ls").methods

  local args = { "--format", "json" }

  if method == methods.FORMATTING then
    table.insert(args, "--fix-dry-run")
    table.insert(args, "--fix-type")
    table.insert(args, table.concat(options.get("code_actions.apply_on_save.types"), ","))
  end

  if options.get("diagnostics.report_unused_disable_directives") then
    table.insert(args, "--report-unused-disable-directives")
  end

  table.insert(args, "--stdin")
  table.insert(args, "--stdin-filename")
  table.insert(args, "$FILENAME")

  return args
end

function M.code_action_handler(params)
  local row = params.row
  local indentation = string.match(params.content[row], "^%s+")
  if not indentation then
    indentation = ""
  end

  local messages = get_messages(params.output)

  local rules, actions = {}, {}
  for _, message in ipairs(messages) do
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
        and options.get("code_actions.disable_rule_comment.enable")
        and not vim.tbl_contains(rules, message.ruleId)
      then
        table.insert(rules, message.ruleId)
        vim.list_extend(actions, generate_disable_actions(message, indentation, params))
      end
    end
  end
  return actions
end

function M.diagnostic_handler(params)
  local messages = get_messages(params.output)

  if params.err then
    table.insert(messages, { message = params.err })
  end

  local helper = require("null-ls.helpers").diagnostics

  local parser = helper.from_json({
    attributes = {
      severity = "severity",
    },
    severities = {
      helper.severities["warning"],
      helper.severities["error"],
    },
  })

  return parser({ output = messages })
end

function M.formatting_handler(params)
  local output = params.output
  local content = output and output[1] and output[1].output

  if not content then
    return
  end

  return {
    {
      row = 1,
      col = 1,
      end_row = #vim.split(content, "\n") + 1,
      end_col = 1,
      text = content,
    },
  }
end

local function get_working_directory()
  local startpath = vim.fn.getcwd()
  return find_git_ancestor(startpath) or find_package_json_ancestor(startpath)
end

function M.config_file_exists()
  local project_root = get_working_directory()

  if project_root then
    return vim.tbl_count(vim.fn.glob(".eslintrc*", true, true)) > 0
  end

  return false
end

---@param cmd string
---@return nil|string
function M.resolve_bin(cmd)
  local project_root = get_working_directory()

  if project_root then
    local local_bin = path_join(project_root, "/node_modules/.bin", cmd)
    if vim.fn.executable(local_bin) == 1 then
      return local_bin
    end
  end

  if vim.fn.executable(cmd) == 1 then
    return cmd
  end

  return nil
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
