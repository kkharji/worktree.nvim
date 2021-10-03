local Worktree = require "worktree.model"
local user = _G.user
if not user then
  error "User not found"
end
local Win = user.ui.float
local pickers = require "worktree.pickers"
local actions = {}

---Create new branch from current working directory
---@param cwd string @current working directory
actions.create = function(cwd)
  cwd = cwd or vim.loop.cwd()
  pickers.pick_branch_type("Pick Branch Type > ", function(choice)
    Win {
      heading = choice.description,
      content = Worktree:template(),
      config = { insert = true, move = { 3, 1 } },
      on_exit = function(_, abort, buflines)
        if abort then
          return
        end
        Worktree:new(buflines, cwd, choice):create()
      end,
    }
  end)
end

---Edit details
---@param cwd string @current working directory
---@param branch_name string @branch name
actions.edit = function(branch_name, cwd)
  cwd = cwd or vim.loop.cwd()
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd)
  Win {
    heading = "Edit Branch Details", -- if info.ispr, change to Edit PR
    content = worktree:as_buffer_content(),
    config = { insert = false, start_pos = { 1, 7 }, move = { { 3, 1 } } },
    on_exit = function(_, abort, content)
      if abort then
        return
      end
      worktree:update(content)
    end,
  }
end

-- worktree.edit()
---Create PR
---@param cwd string @current working directory
---@param branch_name string @branch name
actions.pr_open = function(branch_name, cwd)
  cwd = cwd or vim.loop.cwd()
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd)
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
        worktree:pr_open()
      end
    end,
  }
end

actions.squash_and_merge = function(branch_name, target, cwd)
  local worktree = Worktree:new(branch_name and branch_name or "current", cwd or vim.loop.cwd())
  Win {
    heading = "Squash and Merge",
    content = worktree:as_buffer_content(),
    config = {
      insert = false,
      move = { { 1, 9 } },
      height = "55%",
    },
    on_exit = function(_, abort, content)
      if not abort then
        worktree:update(content)
        --- TODO: Ask user what type of merge he wants
        worktree:squash_and_merge(target or "master") -- TODO: Get main branch name from git global config
      end
    end,
  }
end

return actions
