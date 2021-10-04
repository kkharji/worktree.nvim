local Worktree = require "worktree.model"
local prompt = require "worktree.prompt"
local pickers = require "worktree.pickers"
local user = _G.user
if not user then
  error "User not found"
end
local Win = user.ui.float
local M = {}

---Create new branch from current working directory
---@param cwd string @current working directory
M.create = function(cwd)
  cwd = cwd or vim.loop.cwd()
  --- TODO: Prompt only for name and then edit using M.edit
  pickers.pick_branch_type("Pick Branch Type > ", function(choice)
    prompt {
      heading = choice.prefix:gsub("^%l", string.upper) .. " Branch name (scope: name)",
      default = "",
      on_close = function(aborted, title)
        if aborted then
          return
        end
        --- TODO: make choices configured in config.lua
        Worktree:new(title, cwd, choice):create(choice.template or Worktree:template())
      end,
    }
  end)
end

---Edit details
---@param cwd string @current working directory
---@param branch_name string @branch name
M.edit = function(branch_name, cwd)
  cwd = cwd or vim.loop.cwd()
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd)
  Win {
    heading = "Edit Branch Details", -- if info.ispr, change to Edit PR
    content = worktree:as_buffer_content(),
    config = { insert = false, start_pos = { 1, 7 }, height = "55%" },
    on_exit = function(_, abort, content)
      if abort then
        return
      end
      worktree:update(content)
    end,
  }
end

---Create PR
---@param cwd string @current working directory
---@param branch_name string @branch name
M.pr_open = function(branch_name, cwd)
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd or vim.loop.cwd())
  if worktree.has_pr then
    print "pr is opened or origin remote branch exists."
    return M.edit(name, cwd)
  end
  Win {
    heading = "New Pull Request",
    content = worktree:as_buffer_content(),
    config = {
      insert = false,
      move = { { 1, 9 } },
      height = "55%",
    },
    on_exit = function(_, abort, content)
      if not abort then
        worktree:update(content)
        worktree:pr()
      end
    end,
  }
end

---Merge branch. If there's remote for current branch then merge using github.
---@param branch_name string @name of the branch
---@param target string @name of the branch to merge into.
---@param cwd stringlib
M.merge = function(branch_name, target, cwd)
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd or vim.loop.cwd())
  pickers.pick_branch_merge_type(function(choice)
    Win {
      heading = worktree.has_pr and "PR Merge" or "Local Merge",
      content = worktree:as_buffer_content(),
      config = {
        insert = false,
        move = { { 1, 9 } },
        height = "55%",
      },
      on_exit = function(_, abort, content)
        if not abort then
          worktree:update(content)
          worktree:merge(choice.type, target or "default")
        end
      end,
    }
  end)
end

return M
