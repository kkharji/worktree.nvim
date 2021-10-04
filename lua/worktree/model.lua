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
local Worktree = {}

Worktree.exists = function(self, name)
  return assert.is_branch(name and name or self.name, self.cwd):sync()
end

Worktree.__index = Worktree

---Format buffer according with branch configurations
---@return string[]
Worktree.as_buffer_content = function(self)
  return vim.tbl_flatten { "# " .. self.title, "", unpack(self.body) }
end

---Format with a given branch choice
---@return string[]
Worktree.template = function(_, without_title_placeholder)
  local args = {}
  if not without_title_placeholder then
    args[#args + 1] = "# "
    args[#args + 1] = ""
  end
  args[#args + 1] = "#### Purpose"
  args[#args + 1] = ""
  return args
end

---Parse bufferline to {title, name, body}
---@param bufferlines string[]
---@return WorkTree
Worktree.parse = function(self, bufferlines)
  local p = {}

  if type(bufferlines) == "string" then
    local str = bufferlines
    p.title = str == "current" and fmt.into_title(get.name(self.cwd):sync()[1]) or str
  elseif type(bufferlines) == "table" then
    p.title = bufferlines[1]:gsub("# ", "")
    p.body = vim.trim(table.concat(vim.list_slice(bufferlines, 2, #bufferlines), "\n"))
  end

  if self.type then
    local type = self.type.name:lower()
    if p.title:match ":" then
      local parts = vim.split(p.title, ":")
      p.title = string.format("%s(%s): %s", type, parts[1], parts[2])
    else
      p.title = type .. ": " .. p.title
    end
  end

  p.type = self.type
  p.name = fmt.into_name(p.title)

  if type(bufferlines) == "string" and self:exists(p.name) then
    p.body = get.description(p.name, self.cwd):sync()
  end

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

  --- TOOD: check for invalid names and body, like empty?
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
Worktree.create = function(self, opts) -- TODO: support creating for other than default branch
  body = body and body or self:template(true)
  local has_remote = assert.has_remote(self.cwd)
  local base = opts.base and opts.base or get.default_branch_name(has_remote, self.cwd)

  -- I(opts)

  local checkout = perform.checkout(base, self.cwd)
  local merge = perform.merge_remote(base, self.cwd)
  local new = perform.checkout(self.name, self.cwd)
  local describe = set.description(self.name, table.concat(opts.body, "\n"), self.cwd)

  checkout:after_failure()

  if has_remote then
    checkout:and_then_on_success(merge)
    merge:and_then_on_success(new)
  else
    checkout:and_then_on_success(new)
  end

  new:and_then_on_success(describe)
  describe:after_success(function()
    print(string.format("created '%s' and switched to it", self.name))
  end)
  describe:after_success(function()
    if opts.cb then
      opts.cb(self)
    end
  end)

  checkout:start()
end

Worktree.current_branches = function(self, cwd)
  cwd = cwd or self.cwd
  return get.branches(cwd)
end
---Open new pr for worktree using { buflines } if available
---@param self WorkTree
---@param cb any
Worktree.pr = function(self, cb)
  cb = cb and cb or function() end
  local fetch = perform.fetch(self.cwd)
  local push = perform.push(self.name, self.cwd)
  local fork = perform.gh_fork(self.cwd)
  local create = perform.pr_open(self.title, self.body, self.cwd)

  --- Make sure remote branches are recognized locally.
  fetch:and_then_on_success(push)

  push:and_then_on_success(create)
  create:after(cb)

  push:after_failure(function()
    print "No write access, forking and creating pr instead ..."
    fork:and_then_on_success(create)
    create:after(cb)
    fork:after_failure(function()
      error "Failed to fork repo ..."
    end)
    fork:start()
  end)

  fetch:start()

  self.has_pr = true
end

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
  local o = setmetatable({ cwd = cwd, type = typeinfo }, self)
  local p = o:parse(arg)
  o.name, o.title, o.body = p.name, p.title, p.body
  o.has_pr = assert.has_origin_version(o.name, o.cwd)
  return o
end

return Worktree
