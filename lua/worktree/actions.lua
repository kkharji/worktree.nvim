local view = require "worktree.view"
local pickers = require "worktree.pickers"
local actions = {}

---Create new branch from current working directory
---@param cwd string @current working directory
actions.create = function(cwd)
  cwd = cwd or vim.loop.cwd()
  pickers.pick_branch_type("Pick Branch Type > ", view.create) -- pass list of possible options
end

---Edit details
---@param cwd string @current working directory
---@param name string @branch name
actions.edit = function(name, cwd)
  cwd = cwd or vim.loop.cwd()
  view.edit(name, cwd)
end

-- worktree.edit()
---Create PR
---@param cwd string @current working directory
---@param name string @branch name
actions.pr_open = function(name, cwd)
  cwd = cwd or vim.loop.cwd()
  view.pr_open(name, cwd)
end

return actions
