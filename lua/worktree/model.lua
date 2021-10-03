local jobs = require "worktree.jobs"
local fmt = require "worktree.fmt"

---@class WorkTree
---@field name string
---@field title function
---@field has_pr boolean
---@field body string
---@field type table
---@field cwd string
local w = {
  exists = function(self)
    return jobs.assert.is_branch(self.name, self.cwd()):sync()
  end,
}

w.__index = w

---Format buffer according with branch configurations
---@return string[]
w.as_buffer_content = function(self)
  return vim.tbl_flatten { "# " .. self.title, "", unpack(self.body) }
end

---Format with a given branch choice
---@return string[]
w.template = function(_)
  return { "# ", "", "#### Purpose", "" }
end

---Parse bufferline to {title, name, body}
---@param bufferlines string[]
---@return WorkTree
w.parse = function(_, bufferlines, typeinfo)
  local p = {
    title = bufferlines[1]:gsub("# ", "")
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
w.update = function(self, buflines, cb)
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
    jobs.set.name(self.name, change.name, self.cwd):sync()
  end
  if diff.body then
    jobs.set.description(self.name, change.body, self.cwd):sync()
  end

  self.name = diff.name and change.name or self.name
  self.title = diff.title and change.title or self.title
  self.body = diff.body and change.body or self.body

  if self.has_pr then
    jobs.set.pr_info({
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
w.create = function(self, cb) -- TODO: support creating for other than default branch
  local has_remote = jobs.assert.has_remote(self.cwd)
  local base = jobs.get.default_branch_name(has_remote, self.cwd)


  local checkout = jobs.perform.checkout(base, self.cwd)
  local merge = jobs.perform.merge_remote(base, self.cwd)
  local new = jobs.perform.checkout(self.name, self.cwd)
  local describe = jobs.set.description(self.name, self.body, self.cwd)

    checkout:after_failure(function ()
      print("checkout failed")
    end)


  if has_remote then
    checkout:and_then_on_success(merge)
    merge:and_then_on_success(new)
    merge:after_failure(function ()
      print("merge failed")
    end)
  else
  --- FIXME: doesn't create branch after here
    checkout:and_then_on_success(new)
  end

  new:and_then_on_success(describe)
  describe:after_success(function()
    print(string.format("created '%s' and switched to it", self.name));
    (cb or function() end)()
  end)

  checkout:start()
end

---Open new pr for worktree using { buflines } if available
---@param self WorkTree
---@param cb any
w.pr_open = function(self, cb)
  cb = cb and cb or function() end
  local fetch = jobs.perform.fetch(self.cwd)
  local push = jobs.perform.push(self.name, self.cwd)
  local fork = jobs.perform.fork(self.cwd)
  local create = jobs.perform.pr_open(self.title, self.body, self.cwd)

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

---Squash and merge branch to target.
--TODO: should delete branch automatically
---@param self WorkTree
---@param target string
w.squash_and_merge = function(self, target)
  local checkout = jobs.perform.checkout(target, self.cwd)
  local merge = jobs.perform.squash_and_merge(self.name, self.cwd)
  local commit = jobs.perform.commit(self.title, self.body, self.cwd)
  checkout:and_then_on_success(merge)
  merge:and_then_on_success(commit)
  checkout:start()
end

---@param arg string[]
---@param cwd string @current working directory to repo
---@overload fun(self: WorkTree, name: string, cwd: string): WorkTree
---@return WorkTree
w.new = function(self, arg, cwd, typeinfo)
  local o = { cwd = cwd }

  if type(arg) == "table" then
    local p = self:parse(arg, typeinfo)
    o.name, o.title, o.body, o.type = p.name, p.title, p.body, p.type
  end

  if type(arg) == "string" then
    o.name = arg == "current" and jobs.get.name(cwd):sync()[1] or arg
    o.title = fmt.into_title(o.name)
    o.body = jobs.get.description(o.name, cwd):sync()
  end

  o.has_pr = jobs.assert.has_origin_version(o.name, o.cwd)

  return setmetatable(o, self)
end

return w
