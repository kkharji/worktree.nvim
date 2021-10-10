R "worktree.model"
local Worktree = require "worktree.model"
local pickers = require "worktree.pickers"
local Input = require "worktree.input"
local config = require "worktree.config"
local user = _G.user
local fmt = string.format
local Win = user.ui.float
if not user then
  error "User not found"
end
local M = {}

---Create new branch from current working directory
---@param cwd string @current working directory
M.create = function(cwd, cb)
  cwd = cwd or vim.loop.cwd()
  local choices = config.commits[vim.loop.cwd()] or config.commits.all
  pickers.pick_branch_type {
    title = "Pick Branch Type:",
    choices = vim.tbl_filter(function(choice)
      return not choice.not_branch_type
    end, choices),
    on_submit = function(choice)
      Win {
        heading = choice.description,
        content = Worktree:template(),
        config = { insert = true, start_pos = { 1, 3 }, height = "20%" },
        on_exit = function(_, abort, buflines)
          if abort then
            return (cb or function() end)(false)
          end
          Worktree:new(buflines, cwd, choice):create(cb)
        end,
      }
    end,
  }
end

---Edit details
---@param cwd string @current working directory
---@param branch_name string @branch name
M.edit = function(branch_name, cwd, cb)
  cwd = cwd or vim.loop.cwd()
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd)
  Win {
    heading = "Edit Branch Details", -- if info.ispr, change to Edit PR
    content = worktree:as_buffer_content(),
    config = { insert = false, start_pos = { 1, 7 }, height = "55%" },
    on_exit = function(_, abort, content)
      if abort then
        if cb then
          cb()
        end
      end
      worktree:update(content, cb)
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
    print "pr is opened or origin remote branch exists. Edting instead."
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
        worktree:to_pr()
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

M.switcher = require("worktree.pickers").switcher

M.quick_commit = function(amend, cwd)
  local choices = config.commits[vim.loop.cwd()] or config.commits.all
  local worktree = Worktree:new("current", cwd or vim.loop.cwd())
  local status = worktree:status(true)
  if status == {} then
    return
  end

  --- TODO: should it prompt to add files if nothing is staged?

  local edit = function(content, choice)
    local column = type(choice) == "table" and #choice.prefix + 2 or 15

    Win {
      heading = "Commit to " .. worktree.name,
      content = vim.tbl_flatten { content, status },
      config = {
        insert = amend == nil,
        start_pos = { 1, column },
        filetype = "gitcommit",
      },
      on_exit = function(_, abort, content)
        if not abort then
          worktree:commit(content, amend)
        end
      end,
    }
  end

  if amend then
    edit(worktree:last_commit())
  else
    pickers.pick_branch_type {
      title = "Commit Type:",
      choices = choices,
      on_submit = function(choice)
        Input {
          heading = "commit: (scope, subject) or (subject)",
          on_submit = function(val)
            if not val then
              error "quick_commit: no title given!!"
            end
            local title
            if val:match "," then
              val = vim.split(val, ",")
              local part1 = val[2] and fmt("(%s):", val[1]) or ":"
              local part2 = val[2] and val[2] or val[1]
              title = part1 .. part2
            else
              title = val
            end
            edit(
              vim.tbl_flatten {
                choice.prefix .. title,
                "",
                "",
              },
              choice
            )
          end,
        }
      end,
    }
  end
end

return M
