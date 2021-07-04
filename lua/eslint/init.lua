local options = require("eslint.options")
local null_ls = require("eslint.null-ls")

local M = {}

function M.setup(user_options)
  options.setup(user_options)
  null_ls.setup()
end

return M
