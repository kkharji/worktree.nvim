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

-- #### Issues

-- - [ ] If no origin, creating branches fails
-- - [ ] Edit branch details doesn't have description.
-- - [ ] remove requiring extra space between branch title and body

-- #### Todos

view.edit = function(name, cwd)
  local worktree = Worktree:new(name and name or "current", cwd)
  Win {
    heading = "Edit Branch Details", -- if info.ispr, change to Edit PR
    content = worktree:as_buffer_content(),
    config = { insert = false, start_pos = { 1, 7 }, move = { { 3, 1 } } },
    on_exit = function(_, abort, content)
      if abort then
        return
      end
      worktree:merge(content)
    end,
  }
end

view.pr_open = function(name, cwd)
  local worktree = Worktree:new(name and name or "current", cwd)
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
        worktree:pr_open(content)
      end
    end,
  }
end

return view
