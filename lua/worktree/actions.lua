local msgs = require "worktree.msgs"
local fmt = require "worktree.fmt"
local menu = require "worktree.menu"
local parse = require "worktree.parse"
local M = {}

---TODO: refactor, move assert stuff to assert? and have three main sections of jobs: set, get, perform

local Job = require "worktree.actions.wrapper"

M.get = {}
local get = M.get

get.status = function(self)
  return Job { "git", "status", "--untracked-files", cwd = self.cwd }
end

get.last_commit = function(self)
  return Job { "git", "log", "-1", "--pretty=%B", cwd = self.cwd }
end

get.branches = function(cwd)
  local format = "%(HEAD)"
    .. "%(refname)"
    .. "%(upstream:lstrip=2)"
    .. "%(committerdate:format-local:%Y/%m/%d %H:%M:%S)"

  local output, _ = Job { "git", "for-each-ref", "--perl", "--format", format, cwd = cwd, sync = true }

  for i, line in ipairs(output) do
    output[i] = fmt.parse_branch_info_line(line, cwd)
  end
  table.sort(output, function(a, _)
    return a.current
  end)

  return output
end

---Job to get pr info
---@param cwd string
---@return Job
get.pr_info = function(cwd, cb)
  local job = Job { "gh", "pr", "view", "--json", "title", "--json", "body", cwd = cwd }
  if cb then
    job:after(function(j, code)
      if code ~= 0 then
        return cb(nil)
      end

      cb(vim.json.decode(table.concat(j:result(), "\n")))
    end)
  end

  return job
end

get.parent = function(self, cb)
  local args = { "git", "show-branch", cwd = self.cwd }
  args.on_exit = vim.schedule_wrap(function(j, c)
    if c ~= 0 then
      return cb(nil)
    end
    cb(parse.get_parent(self.name, table.concat(j:result(), "\n")))
  end)

  return Job(args)
end

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
  args.on_exit = (branch_name == "master" or branch_name == "main") and nil or msgs.get_description
  return Job(args)
end

---Get current branch commits
---@param branch_name string
---@param cwd string
---@return Job
get.commits = function(branch_name, cwd)
  local commits = {}
  local curidx = 0
  local base = get.default_branch_name(cwd)
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

get.default_branch_name = function(cwd)
  local default = vim.loop.fs_stat(cwd .. "/.git/refs/heads/master") and "master" or "main"
  if default == "main" then
    local res, _ = Job { "git", "config", "--global", "init.defaultBranch", sync = true }
    default = res[1]
  end
  return default
end

get.last_stash_for = function(branch_name, cwd)
  local name = branch_name
  local stash_list = {}
  if name:match "/" then
    local parts = vim.split(branch_name, "/")
    name = parts[#parts]
  end
  local res, _ = Job { "git", "stash", "list", sync = true, cwd = cwd }
  for _, stash in ipairs(res) do
    if string.match(stash, name) then
      stash_list[#stash_list + 1] = stash
    end
  end

  if #stash_list == 0 then
    return nil
  end

  if #stash_list >= 2 then
    print "There are multiple stashs available, please use :Telescope git_stash. using last stash"
  end

  return string.match(stash_list[1], "(%S+):")
end

get.open_prs = function(cwd)
  local args = { "gh", "pr", "status", "--json", "url", "--json", "headRefName", cwd = cwd }
  return Job(args)
end

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

set.upstream = function(remote, branch_name, cwd)
  local cmd = ("--set-upstream-to=%s/%s"):format(remote, branch_name)
  local args = { "git", "branch", cmd, cwd = cwd }
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

assert.is_dirty = function(cwd)
  local args = { "git", "status", "--porcelain", cwd = cwd }
  return Job(args)
end

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
  return name and name or false
end

M.perform = {}
local perform = M.perform

---Preserve uncommited changes before switching or create new branch, and after
---the main job is ran, pop any changes.
---@param name string
---@param cwd string
---@param main Job
---@return Job
perform.pre_post_switch = function(name, cwd, main)
  local last_stash = get.last_stash_for(name, cwd)
  local is_dirty = assert.is_dirty(cwd)
  is_dirty:after(function(j, _)
    local dirty = not vim.tbl_isempty(j._stdout_results)
    if dirty then
      local stash = perform.stash_push(cwd)
      stash:and_then_on_success(main)
      main:after_success(function()
        if last_stash then
          perform.stash_pop(last_stash, cwd):start()
        end
      end)
      stash:start()
    else
      main:after_success(function()
        if last_stash then
          perform.stash_pop(last_stash, cwd):start()
        end
      end)
      main:start()
    end
  end)

  return is_dirty
end

---Merge remote change for a branch name if any, skip otherwise
--TODO: make it skip if not remote branch
---@param branch_name string
---@param cwd string
---@return Job
perform.merge_remote = function(branch_name, cwd)
  local remote_name = get.remote_name(cwd)
  local args = { "git", "merge", remote_name .. "/" .. branch_name, cwd = cwd }
  args.on_exit = msgs.merge_remote
  return Job(args)
end

---Squash and merge commits from a given branch_name.
---TODO: make it accept target
---@param self WorkTree
---@return Job
perform.squash = function(self)
  local args = { "git", "merge", "--squash", self.name, cwd = self.cwd, on_exit = msgs.squash }
  return Job(args)
end

perform.rebase = function(self)
  local args = { "git", "rebase", self.name, on_exit = msgs.rebase, cwd = self.cwd }
  return Job(args)
end

perform.merge = function(self)
  local args = { "git", "merge", "--no-ff", "-m", "merge: " .. self.name }
  if self.body ~= "" then
    for _, line in ipairs(vim.split(self.body, "\n")) do
      if line ~= "" then
        table.insert(args, "-m")
        table.insert(args, line)
      end
    end
  end
  table.insert(args, self.name)
  args.on_exit = msgs.merge
  args.cwd = self.cwd
  return Job(args)
end

perform.pull = function(branch_name)
  local job = Job { "git", "pull", "origin", branch_name, on_exit = msgs.pull }
  return job
end

perform.switch = function(self)
  return perform.pre_post_switch(
    self.name,
    self.cwd,
    Job {
      "git",
      "switch",
      self.name,
      on_exit = msgs.switch,
    }
  )
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
  local args = { "git", "push", "-u", "origin", branch_name, cwd = cwd, on_exit = msgs.push }
  return Job(args)
end

perform.stash_pop = function(stashhash, cwd)
  return Job { "git", "stash", "pop", stashhash, cwd = cwd, on_exit = msgs.stash_pop }
end

perform.stash_push = function(cwd)
  return Job { "git", "stash", "push", "-u", cwd = cwd, on_exit = msgs.stash_push }
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
---@param self WorkTree
---@param body string[]|nil
---@param special string
---@return Job
perform.commit = function(self, body, special)
  local amend = special == "amend" and "--amend" or nil
  local on_exit = special and msgs[special] or msgs.new_commit

  local args = {}
  if amend then
    args = { "git", "commit", amend }
  else
    args = { "git", "commit" }
  end
  args.on_exit = on_exit
  args.cwd = self.cwd

  for _, line in ipairs(body or self.body) do
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

---Create new branch
-- TODO: support creating for other than default branch
---@param wt WorkTree
---@param cb any
perform.create_branch = function(wt, cb)
  local has_remote = assert.has_remote(wt.cwd)
  local base = get.default_branch_name(wt.cwd)

  local checkout = perform.checkout(base, wt.cwd)
  local merge = perform.merge_remote(base, wt.cwd)
  local new = perform.checkout(wt.name, wt.cwd)
  local set_description = set.description(wt.name, wt.body, wt.cwd)
  -- local set_upstream = set.upstream(wt.name, wt.upstream, wt.cwd)

  checkout:after_failure(function()
    print "checkout failed"
  end)

  if has_remote then
    checkout:and_then_on_success(merge)
    merge:and_then_on_success(new)
    merge:after_failure(function()
      print "merge failed"
    end)
  else
    checkout:and_then_on_success(new)
  end

  new:and_then_on_success(set_description)
  -- new:and_then_on_success(set_upstream)
  -- set_upstream:and_then_on_success(set_description)
  set_description:after_success(vim.schedule_wrap(function()
    print(string.format("created '%s' and switched to it", wt.name));
    (cb or function() end)(wt)
  end))

  perform.pre_post_switch(wt.name, wt.cwd, checkout):start()
end

---Job to create new pr
---@param wt WorkTree
---@return Job
-- fails when the branch is already connected to a pull request
perform.pr_open = function(wt, cb)
  cb = cb and cb or function() end
  local create = {
    "gh",
    "pr",
    "create",
    "--title",
    wt.title,
    "--body",
    table.concat(wt.body, "\n"),
    cwd = wt.cwd,
    on_exit = msgs.pr_open,
  }
  create = Job(create)
  local fetch = perform.fetch(wt.cwd)
  local push = perform.push(wt.name, wt.cwd)
  local fork = perform.gh_fork(wt.cwd)

  --- Make sure remote branches are recognized locally.
  fetch:and_then_on_success(push)

  push:and_then_on_success(create)
  create:after(vim.schedule_wrap(cb))

  push:after_failure(function()
    print "No write access, forking and creating pr instead ..."
    fork:and_then_on_success(create)
    create:after(vim.schedule_wrap(cb))
    fork:after_failure(function()
      error "Failed to fork repo ..."
    end)
    fork:start()
  end)

  fetch:start()

  wt.has_pr = true
end

perform.pr_merge = function(self, type) -- TODO: Support editing body somehow
  local args = { "gh", "pr", "merge", "--" .. type, "--body", table.concat(self.body, "\n"), cwd = self.cwd }
  args.on_exit = msgs["pr_" .. type]
  I(args)
  return Job(args)
end

perform.delete = function(name, current, cwd)
  --- switch to default branch --maybe use switch?
  if current then
    perform.checkout(get.default_branch_name(cwd)):sync()
  end
  Job { "git", "branch", "-D", name, cwd = cwd, on_exit = msgs.delete, sync = true }
end

perform.add = function(self, unstaged_files)
  local args = { "git", "add", cwd = self.cwd }
  args = vim.tbl_flatten { args, unstaged_files }
  args.cwd = self.cwd
  -- args.on_exit = msgs.stage
  return Job(args)
end

M.picker = {}
local picker = M.picker

local s = require "telescope.actions.state"
local a = require "telescope.actions"

picker.delete_branch = function(_)
  local entry = s.get_selected_entry()
  local insert = vim.fn.mode() == "i"
  if insert then
    vim.cmd "stopinsert"
  end

  menu {
    heading = "Delete " .. entry.subject .. "?",
    size = { 3, 30 },
    align_choice = "center",
    choices = {
      { text = "Yes", delete = true },
      { text = "No", delete = false },
    },
    on_close = function(_, choice)
      require("telescope.builtin").resume()
      vim.wait(10)

      if choice ~= nil and choice.delete then
        local picker = s.get_current_picker(vim.api.nvim_get_current_buf())
        picker:delete_selection(function()
          perform.delete(entry.name, entry.current, entry.cwd)
        end)
      end

      if insert then
        vim.cmd "startinsert"
      end
    end,
  }
end

picker.switch_branch = function(bufnr)
  local entry = s.get_selected_entry()
  a.close(bufnr)
  return perform.switch(entry):start()
end

picker.create_branch = function(bufnr)
  local insert = vim.fn.mode() == "i"
  a.close(bufnr)

  if insert then
    vim.cmd "stopinsert"
  end

  require("worktree").create(nil, function(_)
    require("telescope.builtin").resume { cache_index = 2 }

    if insert then
      vim.cmd "startinsert"
    end

    --- TODO: Add new branch to the menu
    -- vim.wait(10)
    -- if entry then
    --   local picker = s.get_current_picker(vim.api.nvim_get_current_buf())
    --   picker:add_selection {
    --     title = entry.title,
    --     subject = fmt.get_subject(entry.title) or entry.title,
    --     scope = (fmt.get_type(entry.title) or "none") .. "/" .. (fmt.get_scope(entry.title) or "*"),
    --     current = entry.name == get.name(entry.cwd):sync()[1],
    --     cwd = entry.cwd,
    --   }
    -- end
  end)
end

picker.edit_branch = function(bufnr)
  local insert = vim.fn.mode() == "i"
  local entry = s.get_selected_entry()
  if insert then
    vim.cmd "stopinsert"
  end
  a.close(bufnr)
  require("worktree").edit(entry.name, entry.cwd, function()
    if insert then
      vim.cmd "startinsert"
    end
    require("telescope.builtin").resume()
  end)
end

picker.create_pr = function(bufnr)
  local entry = s.get_selected_entry()
  a.close(bufnr)
  require("worktree.model"):new(entry.name, entry.cwd):to_pr(function()
    require("telescope.builtin").resume()
  end)
end

picker.open_pr_in_web = function(_)
  local entry = s.get_selected_entry()
  local online = assert.is_online(true)
  local get_open_prs = get.open_prs(entry.cwd)
  online:after_failure(function()
    print("Failed to check whether " .. entry.name .. " has an open pr or not.")
  end)
  online:and_then_on_success(get_open_prs)
  get_open_prs:after(parse.has_pr(entry.name, function(info)
    if not info.url then
      return print("No PR found for " .. info.name .. " (@)")
    end
    --- TODO: support other platforms
    Job({ "open", info.url }):start()
  end))
  online:start()
end

picker.merge_branch = function(_)
  local entry = s.get_selected_entry()
  local insert = vim.fn.mode() == "i"
  local wt = require("worktree.model"):new(entry.name, entry.cwd)
  local targets = get.branches(entry.cwd)
  -- Ask what branch to merge to if it doesn't have a PR, and if it does just
  -- let github handle everything.
  -- or if current branch defer from target branch,
  menu {
    heading = "Choose merge type for " .. entry.subject,
    size = { 3, 30 },
    align_choice = "center",
    choices = {
      { text = "Squash" },
      { text = "Merge" },
      { text = "Rebase" },
    },
    on_close = function(_, choice)
      if choice == nil then
        return print "aborting merge!!"
      end

      table.sort(targets, function(a, b)
        return #a.text < #b.text
      end)

      menu {
        heading = "Choose target Branch to merge into",
        size = { 5, 50 },
        align_choice = "left",
        choices = targets,
        on_close = function(_, branch)
          if not branch then
            require("telescope.builtin").resume()
            return
          end
          wt:merge(choice.text:lower(), branch.text, function()
            require("telescope.builtin").resume()
            if insert then
              vim.cmd "startinsert"
            end
            return
          end)
        end,
      }
      --- ASK which branch to merge into? current or default
      -- wt:merge(choice.text,)
    end,
  }
end

return M
