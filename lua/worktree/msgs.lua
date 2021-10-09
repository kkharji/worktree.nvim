local M = {}
M.pull = {
  err = "failed to merge remote to branch",
}

M.checkout = {
  err = "Failed to checked out/created a new branch",
}

M.merge_remote = {
  err = "Failed to merge remote version of given or default branch",
}

M.squash = {
  err = "Failed to squash and merge",
  pass = "Successfully Squashed and merged to target branch",
}

M.merge = {
  err = "Failed to merge and create merge commit",
  pass = "Successfully merged to target branch with a merge commit",
}

M.rebase = {
  err = "Failed to rebase and merge commit to target branch",
  pass = "Successfully rebased and merged to target branch",
}

M.get_name = {
  err = "Failed to get current branch name",
}

M.get_description = {
  err = "no description found, creating a new description ..",
  highlight_as_normal = true,
}

M.set_name = {
  err = "Failed to update name",
  pass = "Updated branch name",
}

M.switch = {
  err = "Failed to switch to target branch",
  pass = "Successfully switched to target branch",
}

M.set_description = {
  err = "Failed to update branch description",
}

M.sync_current_info = {
  err = "Failed to sync branch/pr info",
}

M.get_current_info = {
  err = "Failed to get branch/pr info ",
}

M.offline_save = {
  err = "Unable to sync changes to remote PR. Saving locally instead.",
  pass = "Syncing changes to remote ...",
}

M.push = {
  err = "Failed to push %s to remote",
  pass = "Successfully pushed to remote ...",
}

M.fork = {
  err = "Failed to fork",
  pass = "Successfully Forked target repo",
}

M.pr_open = {
  err = "Failed to create a pull request",
  pass = "Successfully created a pull request",
}

M.pr_info = {
  err = "Failed to get pull request information",
}

M.pr_squash = {
  err = "Failed to squash and merge using github-cli",
  pass = "Successfully squashed and merged target branch using github-cli.",
}

M.pr_rebase = {
  err = "Failed to rebase and merge using github-cli",
  pass = "Successfully rebased target branch using github-cli.",
}

M.pr_update = {
  err = "Failed to sync pr info for",
  pass = "Successfully synced local branch description changes with remote",
}

M.pr_merge = {
  err = "Failed to merge and create merge commit using github-cli",
  pass = "Successfully merged and rebased with a merge commit using github-cli.",
}

M.delete = {
  err = "Failed to delete branch",
  pass = "Successfully delete target branch",
}

M.stash_pop = {
  err = "Failed to pop stash",
  pass = "Successfully popped last stash for the current branch",
}

M.stash_push = {
  err = "Failed to push uncommited changes and untracked files. aborting",
  pass = "Successfully saved currently uncommited changes and untracked files.",
}

for key, group in pairs(M) do
  M[key] = vim.schedule_wrap(function(j, code, _)
    if code == 0 and group.pass then
      vim.api.nvim_echo({ { group.pass, "healthSuccess" } }, true, {})
    elseif code ~= 0 and group.err then
      local msg = group.err
      local highlight = "WarningMsg"
      if not group.highlight_as_normal then
        msg = msg .. ": " .. table.concat(j:stderr_result(), "\n")
        highlight = "normal"
      end
      vim.api.nvim_echo({ { msg, highlight } }, true, {})
    end
  end)
end

-- TODO: pass arguments using index. M[key] should return both call and __index that return a function using the index value as arugments
-- msgs.switch[{ "branch name" }]

return M
