local branch_fmt = require "worktree.fmt"
local assert = require "worktree.assert"
local util = require "worktree.util"
local jobs = {}

local Job = function(o)
  local job = require("plenary.job"):new(o)
  if o.sync then
    return job:sync()
  end
  return job
end

local notify = util.notify {
  checkout = { "Failed to checkout/create %s: %s", "checked out/created %s" },
  merge = { "Failed to merge %s/%s/: %s" },
  get_name = { "Failed to get current branch name of %s: %s" },
  get_description = { "Creating new Description" },
  set_name = { "Failed to update name from '%s' to '%s': %s", "Updated name from '%s' to '%s'" },
  set_description = { "Failed to update branch description to %s: %s" },
  pr_open = { "Failed to create a pull request: %s", "pull request has been created successfully." },
  pr_update_body = { "Failed to update pr body for %s: ", "pr body has been updated successfully" },
  pr_update_title = { "Failed to update pr title for %s: ", "pr title has been updated successfully" },
  pr_get_info = { "Failed to get pr info for %s: " },
  pr_sync_info = { "Failed to sync pr info for %s: ", "PR is successfully synced!!" },
  sync_current_info = { "Failed to sync branch/pr info for %s: " },
  get_current_info = { "Failed to get branch/pr info for %s: " },
  offline_save = { "Unable to sync changes to remote PR. Saving locally instead.", "Syncing changes to remote ..." },
}

jobs.iserr = function(code, type)
  if code == 0 then
    return false
  end
  notify(type)
  return false
end

jobs.get_remote = function(cwd)
  local remote = "origin"
  local args = { "git", "config", "remote.upstream.url", cwd = cwd, sync = true }
  args.on_exit = function(_, c)
    if c == 0 then
      remote = "upstream"
    end
  end

  Job(args)
  return remote
end

jobs.fetch = function(cwd) -- used in case of commits and tags_to_string
  local args = { "git", "fetch", "--depth=999999", "--progress", cwd = cwd }
  return Job(args)
end

jobs.push = function(branch_name, cwd)
  local args = { "git", "push", "-u", jobs.get_remote(cwd), branch_name, cwd = cwd }
  return Job(args)
end

jobs.checkout = function(branch_name, cwd)
  local base = (branch_name == "master" or branch_name == "main")
  local args = base and { "git", "checkout", branch_name, cwd = cwd }
    or { "git", "checkout", "-b", branch_name, cwd = cwd }
  args.on_exit = notify("checkout", branch_name)
  return Job(args)
end

jobs.merge = function(branch_name, cwd)
  local remote = jobs.get_remote(cwd)
  local args = { "git", "merge", remote, branch_name, cwd = cwd }
  args.on_exit = notify("merge", remote, branch_name)
  return Job(args)
end

jobs.get_name = function(cwd)
  local args = { "git", "rev-parse", "--abbrev-ref", "HEAD", cwd = cwd }
  args.on_exit = notify("get_name", cwd)
  return Job(args)
end

jobs.get_title = function(name)
  return branch_fmt.into_title(name)
end

jobs.has_remote = function(branch_name, cwd)
  -- error(vim.inspect(branch_name))
  --- Could origin be something else in every day use?
  local args = { "git", "branch", "-r", "--list", "origin/" .. branch_name, sync = true, cwd = cwd }
  local remote = Job(args)
  return remote[1] ~= nil
end

jobs.get_description = function(branch_name, cwd)
  local path = string.format("branch.%s.description", branch_name)
  local args = { "git", "config", path, cwd = cwd }
  args.on_exit = notify("get_description", cwd)
  return Job(args)
end

jobs.get_commits = function(branch_name, cwd)
  local commits = {}
  local curidx = 0
  local base = "master" --- TODO: get base branch automatically
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

--- TODO: (updating branch name) should fail when remote branch exists or update remote??
jobs.set_name = function(branch_name, new, cwd)
  local args = { "git", "branch", "-m", branch_name, new, cwd = cwd }
  args.on_exit = notify("set_name", branch_name, new)

  if cwd == vim.loop.cwd() then
    vim.g.gitsigns_head = new
    vim.api.nvim_buf_set_var(0, "gitsigns_head", new)
  end
  return Job(args)
end

jobs.is_branch = function(branch_name, cwd)
  local args = { "git", "show-ref", "--quiet", "refs/heads/" .. branch_name, cwd = cwd }
  args.on_exit = function(j, code)
    j._stdout_results = code ~= 0
  end
  return Job(args)
end

jobs.set_description = function(branch_name, description, cwd)
  local path = string.format("branch.%s.description", branch_name)
  local args = { "git", "config", path, description, cwd = cwd }
  args.on_exit = notify("set_description", description)
  return Job(args)
end

jobs.update_local_info = function(org, new)
  local diff = {}
  local update_name, update_body

  if new.name ~= org.name then
    update_name = jobs.set_name(org.name, new.name, org.cwd)
    diff.name = true
    diff.title = true
  end
  if new.body ~= org.body then
    update_body = jobs.set_description(org.name, org.body, org.cwd)
    diff.body = true
  end

  if not update_name and not update_body then
    return
  end

  if update_name and not update_body then
    update_name:start()
  elseif update_body and not update_name then
    update_body:start()
  else
    update_name:and_then_on_success(update_body)
    update_name:start()
  end

  return diff
end

jobs.repo_fork = function(cwd)
  return Job { "gh", "repo", "fork", "--remote=true", cwd = cwd }
end

---Job to get pr info
---@param cwd string
---@return Job
jobs.pr_get_info = function(cwd)
  return Job { "gh", "pr", "view", "--json", "title", "--json", "body", cwd = cwd }
end

---Job to update info
---@param cwd string
---@return Job
jobs.pr_update = function(fields, cwd)
  local start = assert.is_online(true)
  local cb = fields.cb
  fields.cb = nil
  local args = { "gh", "pr", "edit", on_exit = notify("pr_sync_info", cwd) }
  for field, value in pairs(fields) do
    table.insert(args, "--" .. field)
    table.insert(args, value)
  end
  local update = Job(args)

  start:after_failure(vim.schedule_wrap(function(_, code)
    if jobs.iserr(code, "is_online") then
      return
    end
  end))
  start:and_then_on_success(update)
  update:after_success(vim.schedule_wrap(cb))

  return start
end

---Job to create new pr
---@param cwd string
---@return Job
-- fails when the branch is already connected to a pull request
jobs.pr_open = function(title, body, cwd)
  local args = { "gh", "pr", "create", "--title", title, "--body", body, cwd = cwd }
  args.on_exit = notify "pr_open"
  return Job(args)
end

return jobs
