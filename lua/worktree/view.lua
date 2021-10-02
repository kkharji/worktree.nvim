local view = {}
local Worktree = require "worktree.model"
local user = _G.user
if not user then
  error "User not found"
end
local Win = user.ui.float

view.create = function(typeinfo, cwd)
  Win {
    heading = typeinfo.description,
    content = Worktree:template(),
    config = { insert = true, move = { 3, 1 } },
    on_exit = function(_, abort, buflines)
      if abort then
        return
      end
      Worktree:new(buflines, cwd, typeinfo):create()
    end,
  }
end

view.edit = function(branch_name, cwd)
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

view.pr_open = function(branch_name, cwd)
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

view.squash_and_merge = function(branch_name, target, cwd)
  local name = branch_name and branch_name or "current"
  local worktree = Worktree:new(name, cwd)
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
        worktree:merge(target)
      end
    end,
  }
end

return view
