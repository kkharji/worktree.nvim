local msgs = require "worktree.msgs"
local fmt = require "worktree.fmt"
local M = {}

---TODO: refactor, move assert stuff to assert? and have three main sections of jobs: set, get, perform

local Job = function(o)
  local job = require("plenary.job"):new(o)
  if o.sync then
    return job:sync()
  end
  return job
end

M.get = {}
local get = M.get

---Check whether a branch has a upstream/origin repo
---@param cwd string
---@return Job
get.remotes = function(cwd)
  local args = { "git", "remote", cwd = cwd }
  args.on_exit = function(j, _)
    local ret = {}
    for _, value in ipairs(j._stdout_results) do
      ret[value] = true
    end
    j._stdout_results = ret
  end
  return Job(args)
end

---Get remote name. Here is hacky way of doing it. check if upstream passes, if so make upstream.
---@param cwd string
---@return string
get.remote_name = function(cwd)
  local remotes = get.remotes(cwd):sync()
  if remotes.upstream then
    return "upstream"
  elseif remotes.origin then
    return "origin"
  end
end

---Get current branch name
---@param cwd string
---@return Job
get.name = function(cwd)
  return Job { "git", "rev-parse", "--abbrev-ref", "HEAD", cwd = cwd, on_exit = msgs.get_name }
end

---Get branch description
---@param branch_name string
---@param cwd string
---@return Job
get.description = function(branch_name, cwd)
  local path = string.format("branch.%s.description", branch_name)
  local args = { "git", "config", path, cwd = cwd }
  args.on_exit = msgs.get_description
  return Job(args)
end

---Get current branch commits
---@param branch_name string
---@param cwd string
---@return Job
get.commits = function(branch_name, cwd)
  local commits = {}
  local curidx = 0
  local base = get.default_branch_name(assert.has_remote(cwd), cwd)
  local range = string.format("%s..%s", base, branch_name)
  local args = { "git", "log", range, "--oneline", "--reverse", "--format=X<<%s%n%n%b", cwd = cwd }
  args.on_stdout = function(_, line)
    if line:sub(1, 3) == "X<<" then
      curidx = curidx + 1
      commits[curidx] = { title = line:gsub("X<<", ""), body = {} }
    elseif commits[curidx].title then
      table.insert(commits[curidx].body, line)
    end
  end
  args.on_exit = function(j)
    j._stdout_results = commits
  end
  return Job(args)
end

get.default_branch_name = function(has_remote, cwd)
  local default = ""
  if has_remote then
    default = vim.loop.fs_stat(cwd .. "/.git/refs/heads/master") and "master" or "main"
  else
    local res, _ = Job { "git", "config", "--global", "init.defaultBranch", sync = true }
    default = res[1]
  end

  return default
end

get.branches = function(cwd)
  local res = { { text = "Default", name = get.default_branch_name(false, cwd) } }
  local output, _ = Job { "git", "branch", cwd = cwd, sync = true }
  for _, branch in ipairs(output) do
    branch = vim.trim(branch)
    if branch:match "*" then
      branch = vim.trim(branch:gsub("*", ""))
      res[#res + 1] = {
        current = true,
        text = "Current",
        name = branch,
        title = fmt.into_title(branch),
      }
    elseif branch ~= "master" and branch ~= "name" then
      local title = fmt.into_title(branch)
      res[#res + 1] = { text = title, title = title, name = branch }
    end
  end

  return res
end

-- I(get.branches(vim.loop.cwd()))

M.set = {}
local set = M.set
---Update branch name
---@param branch_name string
---@param new string
---@param cwd string
---@return Job
set.name = function(branch_name, new, cwd)
  --- TODO: (updating branch name) should either fail when remote branch exists or update remote local and remote
  local args = { "git", "branch", "-m", branch_name, new, cwd = cwd }
  args.on_exit = msgs.set_name

  if cwd == vim.loop.cwd() then -- FIXME: this doesn't always work
    vim.g.gitsigns_head = new
    vim.api.nvim_buf_set_var(0, "gitsigns_head", new)
  end
  return Job(args)
end

---Update branch local description
---@param branch_name string
---@param description string
---@param cwd string
---@return Job
set.description = function(branch_name, description, cwd)
  local path = string.format("branch.%s.description", branch_name)
  return Job { "git", "config", path, description, cwd = cwd, on_exit = msgs.set_description }
end

M.assert = {}
local assert = M.assert

---Check if user is connect to the network
---@param as_job any
---@return boolean
assert.is_online = function(as_job)
  local check = { "ping", "-c", "1", "github.com" }
  if not as_job then
    check.sync = true
    local _, code = Job(check)
    return code == 0
  end
  return Job(check)
end

---Check if a given branch_name exists
---@param branch_name string
---@param cwd string
---@return Job
assert.is_branch = function(branch_name, cwd)
  local args = { "git", "show-ref", "--quiet", "refs/heads/" .. branch_name, cwd = cwd }
  args.on_exit = function(j, code)
    j._stdout_results = code == 0
  end
  return Job(args)
end

---Check if a {branch_name} has remote version.
---@param branch_name string
---@param cwd any
---@return boolean
assert.has_origin_version = function(branch_name, cwd)
  --- TODO: Could origin be something else in every-day use?
  local args = { "git", "branch", "-r", "--list", "origin/" .. branch_name, sync = true, cwd = cwd }
  local remote = Job(args)
  return remote[1] ~= nil
end

---check if repo has remote branch
---@param cwd string
assert.has_remote = function(cwd)
  local name = get.remote_name(cwd)
  return not name and false or true
end

M.perform = {}
local perform = M.perform

---Merge remote change for a branch name if any, skip otherwise
--TODO: make it skip if not remote branch
---@param cwd string
---@return Job
perform.merge_remote = function(base, cwd)
  local remote_name = get.remote_name(cwd)
  local args = { "git", "merge", remote_name .. "/" .. base, cwd = cwd }
  args.on_exit = msgs.merge_remote
  return Job(args)
end

---Squash and merge commits from a given branch_name.
---TODO: make it accept target
---@param branch_name string
---@param cwd string
---@return Job
perform.squash = function(branch_name, cwd)
  local name = branch_name == "default" and get.default_branch_name(false, cwd)
  local args = { "git", "merge", "--squash", name, cwd = cwd, on_exit = msgs.squash }
  return Job(args)
end

perform.rebase = function(branch_name, cwd)
  local args = { "git", "rebase", branch_name, on_exit = msgs.rebase, cwd = cwd }
  return Job(args)
end

perform.merge = function(branch_name, body, cwd)
  local args = { "git", "merge", "--no-ff", "-m", "merge: " .. branch_name }
  if body ~= "" then
    for _, line in ipairs(vim.split(body, "\n")) do
      if line ~= "" then
        table.insert(args, "-m")
        table.insert(args, line)
      end
    end
  end
  table.insert(args, branch_name)
  args.on_exit = msgs.merge
  args.cwd = cwd
  return Job(args)
end

---Fetch new changes from remote.
-- TODO: make it ignore fetching if not remote is avaliable
-- TODO: which remote?
---@param cwd any
---@return Job
perform.fetch = function(cwd)
  local args = { "git", "fetch", "--depth=999999", "--progress", cwd = cwd }
  return Job(args)
end

---Push changes for a given branch_name to remote
--TODO: catch and prit errors. Also ignore if no remote is avaliable.
---@param branch_name string
---@param cwd string
---@return Job
perform.push = function(branch_name, cwd)
  local remote = get.remote_name(cwd)
  local args = { "git", "push", "-u", remote, branch_name, cwd = cwd, on_exit = msgs.push }
  return Job(args)
end

---Checkout a given branch name. If branch name is master or main then then simply switch?
---@param branch_name string
---@param cwd string
---@return Job
perform.checkout = function(branch_name, cwd)
  local base = (branch_name == "master" or branch_name == "main")
  local args = base and { "git", "checkout", branch_name, cwd = cwd }
    or { "git", "checkout", "-b", branch_name, cwd = cwd }
  args.on_exit = msgs.checkout
  return Job(args)
end

---Make a commit
---@param heading string @commit heading
---@param body string @commit body
---@param cwd string @path where the git command should be executed
---@return Job
perform.commit = function(heading, body, cwd, special)
  local on_exit = special and msgs[special] or msgs.new_commit
  local args = { "git", "commit", "-m", heading, cwd = cwd, on_exit = on_exit }
  body = vim.split(body, "\n")
  for _, line in ipairs(body) do
    if line ~= "" then
      args[#args + 1] = "-m"
      args[#args + 1] = line
    end
  end

  return Job(args)
end

---Job to fork remote repo to origin and change current to upstream
---@param cwd string
---@return Job
perform.gh_fork = function(cwd)
  return Job { "gh", "repo", "fork", "--remote=true", cwd = cwd, on_exit = msgs.fork }
end

---Job to get pr info
---@param cwd string
---@return Job
get.pr_info = function(cwd)
  return Job { "gh", "pr", "view", "--json", "title", "--json", "body", cwd = cwd }
end

---Job to update info
---@param cwd string
---@return Job
perform.pr_update = function(fields, cwd)
  local start = assert.is_online(true)
  local cb = fields.cb
  fields.cb = nil
  local args = { "gh", "pr", "edit", on_exit = msgs.pr_update }
  for field, value in pairs(fields) do
    table.insert(args, "--" .. field)
    table.insert(args, value)
  end
  local update = Job(args)

  start:after_failure(msgs.offline_save)
  start:and_then_on_success(update)
  if cb then
    update:after_success(vim.schedule_wrap(cb))
  end

  return start
end

---Job to create new pr
---@param cwd string
---@return Job
-- fails when the branch is already connected to a pull request
perform.pr_open = function(title, body, cwd)
  return Job { "gh", "pr", "create", "--title", title, "--body", body, cwd = cwd, on_exit = msgs.pr_open }
end

perform.pr_squash = function(body, cwd)
  local args = { "gh", "pr", "merge", "--delete-branch", "--squash", "--body", body, cwd = cwd }
  args.on_exit = msgs.pr_squash
  return Job(args)
end

perform.pr_rebase = function(body, cwd)
  local args = { "gh", "pr", "merge", "--rebase", "--delete-branch", "--body", body, cwd = cwd }
  args.on_exit = msgs.pr_rebase
  return Job(args)
end

perform.pr_merge = function(body, cwd)
  local args = { "gh", "pr", "merge", "--merge", "--delete-branch", "--body", body, cwd = cwd }
  args.on_exit = msgs.pr_rebase
  return Job(args)
end

return M
