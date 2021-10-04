local actions = require "worktree.actions"
local assert, perform, get, set = actions.assert, actions.perform, actions.get, actions.set
local fmt = require "worktree.fmt"

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

  if self.has_pr then
    perform.pr_update({
      title = diff.title and self.title or nil,
      body = diff.body and self.body or nil,
      cb = cb,
    }):start()
  else
    (cb or function() end)()
  end
end

---Create new branch through checking out master, merging recent remote,
---checking out the new branch out of base and lastly set description
Worktree.create = perform.create_branch

---Open new pr for worktree using { buflines } if available
---@param self WorkTree
---@param cb any
Worktree.to_pr = perform.pr_open

---@param self WorkTree
---@param target string
---@param type '"squash"' | '"rebase"' | '"merge"'
Worktree.merge = function(self, type, target)
  if target == "default" then
    target = get.default_branch_name(self.has_pr, self.cwd)
  end

  return self["merge_" .. type](self, target)
end

Worktree.fetch = function(self)
  local job = assert.is_online(true)
  job:and_then_on_success(perform.fetch(self.cwd))
  return job
end

---Squash and merge branch to target.
---@param target string
--TODO: should delete branch automatically
Worktree.merge_squash = function(self, target)
  local fetch = self:fetch()
  if not self.has_pr then
    local checkout = perform.checkout(target, self.cwd)
    local merge = perform.squash_and_merge(self.name, self.cwd)
    local commit = perform.commit(self.title, self.body, self.cwd, "squash")
    fetch:and_then(checkout)
    checkout:and_then_on_success(merge)
    merge:and_then_on_success(commit)
  else
    local gh_action = perform.pr_squash(self.body, self.cwd)
    fetch:and_then(gh_action)
  end
  fetch:start()
end

---Rebase branch or remote branch using gituhb
---@param target string
--TODO: should delete branch automatically
Worktree.merge_rebase = function(self, target)
  local fetch = self:fetch()
  if not self.has_pr then
    local checkout = perform.checkout(target, self.cwd)
    local rebase = perform.rebase(self.name, self.cwd)
    fetch:and_then(checkout)
    checkout:and_then_on_success(rebase)
  else
    local gh_action = perform.pr_rebase(self.body, self.cwd)
    fetch:and_then(gh_action)
  end
  fetch:start()
end

---Merge with a commit
---@param target string
--TODO: should delete branch automatically
Worktree.merge_merge = function(self, target)
  local fetch = self:fetch()
  if not self.has_pr then
    local checkout = perform.checkout(target, self.cwd)
    local merge = perform.merge(self.name, self.body, self.cwd)
    fetch:and_then(checkout)
    checkout:and_then_on_success(merge)
  else
    local gh_action = perform.pr_merge(self.body, self.cwd)
    fetch:and_then(gh_action)
  end
  fetch:start()
end

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

return Worktree
