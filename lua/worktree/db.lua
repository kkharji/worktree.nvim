local sqlite = require "sqlite"
local fmt = require ".worktree.fmt"

--- TODO: Support changing directory path?

---@class bptbl_entry
---@field name string
---@field title string @(computed)
---@field body string
---@field has_pr boolean
---@field doc number @(epoch) date of creation
---@field last_visited number @(epoch) date of last visit
---@field last_sync number? @(epoch) is nil when there isn't any PR Open
---@field out_of_sync boolean
---@field cwd string @current working directory
---@field priority string @A,B,C,D
---@field repo_name string @(computed) name of the repo
local now = sqlite.lib.strftime("%s", "now")

---@type sqlite_tbl
local tbl = sqlite({
  -- uri = user.dbdir .. "/main.db",
  data = {
    name = { "text", required = true, primary = true },
    body = { "text", required = true, default = "'### Purpose\n\n### Pending\n\n### Done'" },
    has_pr = "boolean",
    doc = { "date", default = now, required = true },
    last_visited = { "date", default = now, required = true },
    last_sync = "date",
    cwd = { "text", required = true },
    priority = { "text", required = true, default = "D" },
  },
}).data

return setmetatable({}, {
  __index = function(_, name)
    local branch = tbl:where { name = name }
    if not branch then
      return nil
    end

    branch.title = fmt.into_title(branch.name)
    branch.repo_name = (function()
      local l = vim.split(branch.cwd, "/")
      return l[#l]
    end)()
    tbl:update { where = { name = name }, last_visited = now }
    return branch
  end,
  __new_index = function(_, name, data)
    tbl:update {
      set = {
        body = data.body and table.concat(data.body, "\n") or nil,
        has_pr = data.has_pr,
        last_sync = (data.has_pr and data.synced) and now or nil,
        out_of_sync = (data.has_pr and data.out_of_sync) and true or false,
        cwd = data.cwd,
        priority = data.priority,
      },
      where = { name = name },
    }
  end,
  call = nil,
})
