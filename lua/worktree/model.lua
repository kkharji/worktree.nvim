local actions = require "worktree.actions"
local assert, perform, get, set = actions.assert, actions.perform, actions.get, actions.set
local fmt = require "worktree.fmt"
local parse = require "worktree.parse"

---@class WorkTree
---@field name string
---@field title function
---@field has_pr boolean
---@field body string
---@field type table
---@field cwd string
---@field upstream string @name of upstream repo
local Worktree = {
  exists = function(self, name)
    return assert.is_branch(name or self.name, self.cwd):sync()
  end,
}

---@param arg string[]
---@param cwd string @current working directory to repo
---@overload fun(self: WorkTree, name: string, cwd: string): WorkTree
---@return WorkTree
Worktree.new = function(self, arg, cwd, typeinfo)
  local o = { cwd = cwd }

  if type(arg) == "table" then
    local p = self:parse(arg, typeinfo)
    o.name, o.title, o.body, o.type = p.name, p.title, p.body, p.type
  end

  if type(arg) == "string" then
    o.name = arg == "current" and get.name(cwd):sync()[1] or arg
    o.title = fmt.into_title(o.name)
    o.body = get.description(o.name, cwd):sync()
  end

  o.has_pr = assert.has_origin_version(o.name, o.cwd)
  o.upstream = get.remote_name(o.cwd)

  return setmetatable(o, self)
end

Worktree.__index = Worktree

---Format buffer according with branch configurations
---@return string[]
Worktree.as_buffer_content = function(self)
  return vim.tbl_flatten { "# " .. self.title, "", unpack(self.body) }
end

---Format with a given branch choice
---@return string[]
Worktree.template = function(_)
  return { "# ", "", "#### Purpose", "" }
end

---Parse bufferline to {title, name, body}
---@param bufferlines string[]
---@return WorkTree
Worktree.parse = function(_, bufferlines, typeinfo)
  local p = {
    title = bufferlines[1]:gsub("# ", ""),
  }

  if typeinfo then
    local type = typeinfo.name:lower()
    if p.title:match ":" then
      local parts = vim.split(p.title, ":")
      p.title = string.format("%s(%s): %s", type, parts[1], parts[2])
    else
      p.title = type .. ": " .. p.title
    end
  end

  p.type = typeinfo
  p.name = fmt.into_name(p.title)
  p.body = vim.trim(table.concat(vim.list_slice(bufferlines, 2, #bufferlines), "\n"))
  return p
end

---Merge and update changes made in a branch
---Reflect changes made in written format with local name, description and if
---the branch has pr, update pr
---@param buflines string[]
Worktree.update = function(self, buflines, cb)
  if not buflines then
    if cb then
      cb()
    end
    return
  end
  local change = self:parse(buflines)
  local diff = {}

  diff.name = self.name ~= change.name
  diff.title = self.title ~= change.title
  diff.body = self.body ~= change.body

  if diff.name then
    set.name(self.name, change.name, self.cwd):sync()
  end
  if diff.body then
    set.description(change.name, change.body, self.cwd):sync()
  end

  self.name = diff.name and change.name or self.name
  self.title = diff.title and change.title or self.title
  self.body = diff.body and change.body or self.body

  get.pr_info(self.cwd, function(info)
    if info and (info.title ~= info.title or info.body ~= self.body) then
      perform.pr_update {
        title = self.title,
        body = self.body,
        cb = cb,
      }
    else
      (cb or function() end)()
    end
  end):start()
end

---Create new branch through checking out master, merging recent remote,
---checking out the new branch out of base and lastly set description
Worktree.create = perform.create_branch

---Open new pr for worktree using { buflines } if available
---@param self WorkTree
---@param cb any
Worktree.to_pr = perform.pr_open

local do_locally = function(self, type, checkout, cb)
  local cb = cb or function() end
  local run = perform[type](self)

  if not run then
    print(type .. " is not supported.")
    return
  end
  checkout:and_then_on_success(run)

  if type == "squash" then
    local commit = perform.commit(self, "squash")
    run:and_then_on_success(commit)
    commit:after(vim.schedule_wrap(cb))
  else
    run:after(vim.schedule_wrap(cb))
  end
  checkout:start()
end

---@param self WorkTree
---@param target string
---@param type '"squash"' | '"rebase"' | '"merge"'
Worktree.merge = function(self, type, target, cb)
  local isonline = assert.is_online(true)
  local fetch = perform.fetch(self.cwd)
  local checkout = perform.checkout(target, self.cwd)
  target = target == "default" and get.default_branch_name(self.cwd) or target
  cb = vim.schedule_wrap(cb or function() end)

  isonline:and_then_on_success(fetch)
  fetch:and_then_wrap(get.pr_info(self.cwd, function(info)
    if info == nil then
      return do_locally(self, type, checkout, cb)
    end
    local push = perform.push(self.name, self.cwd)
    local merge = perform.pr_merge(self, type)

    push:and_then_on_success(merge)
    merge:and_then_on_success_wrap(get.parent(self, function(parent)
      if not parent then
        print "parent not found"
        return
      end
      print "reflect changes locally"
      local switch = perform.switch { name = parent, cwd = self.cwd }
      local pull = perform.pull(parent)
      switch:and_then_on_success(pull)
      pull:and_then_on_success(cb)
    end))
    push:start()
  end))

  isonline:after_failure(function()
    print "using local"
    -- do_locally(self, type, checkout, cb)
  end)

  isonline:start()
end

return Worktree
