local M = {}

M.checkout = {
  err = "Failed to checkout/create %s: %s",
  pass = "checked out/created %s",
}

M.merge_remote = {
  err = "Failed to merge %s/%s/: %s",
}

M.squash_and_merge = {
  err = "Failed to squash and merge %s: %s",
  pass = "Squashed and merged successfully %s",
}

M.get_name = {
  err = "Failed to get current branch name of %s: %s",
}

M.get_description = {
  err = "Creating new Description ..",
}

M.set_name = {
  err = "Failed to update name from '%s' to '%s': %s",
  pass = "Updated branch name from '%s' to '%s'",
}

M.set_description = {
  err = "Failed to update branch description to %s: %s",
}

M.pr_open = {
  err = "Failed to create a pull request: %s",
  pass = "pull request has been created successfully.",
}

M.pr_info = {
  err = "Failed to get pr info for %s: ",
}

M.pr_update = {
  err = "Failed to sync pr info for %s: ",
  pass = "PR is synced successfully",
}

M.sync_current_info = {
  err = "Failed to sync branch/pr info for %s: ",
}

M.get_current_info = {
  err = "Failed to get branch/pr info for %s: ",
}

M.offline_save = {
  err = "Unable to sync changes to remote PR. Saving locally instead.",
  pass = "Syncing changes to remote ...",
}

M.push = {
  err = "Failed to push %s to remote: %s",
  pass = "Pushed %s successfully to remote ..."
}

M.fork = {
  err = "Failed to fork %s: %s.",
  pass = "Forked %s successfully."
}

local tostr = function(msg, ...)
  local args = { ... }
  local count = select(2, msg:gsub("%%s", ""))
  if count ~= #args and count > #args then
    while count ~= #args do
      table.insert(args, "")
    end
  end
  return string.format(msg, unpack(args))
end

--- TODO: use notify.nvim
local construct = function(msgs)
  return function(job_type, ...)
    local group = msgs[job_type]
    local args = { ... }
    return vim.schedule_wrap(function(j, code)
      if code ~= 0 and group.err then
        args[#args + 1] = table.concat(j:stderr_result(), "\n")
        vim.api.nvim_echo({ { tostr(group.err, unpack(args)), "WarningMsg" } }, true, {})
      elseif group[2] then
        vim.api.nvim_echo({ { tostr(group.pass, unpack(args)), "healthSuccess" } }, true, {})
      end
    end)
  end
end

local notify = construct(M)

return setmetatable({}, {
  __index = function(_, key)
    return function(...)
      return notify(key, ...)
    end
  end,
})
