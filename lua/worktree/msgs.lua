local M = {}

M.checkout = {
  err = "Failed to checked out/created a new branch",
}

M.merge_remote = {
  err = "Failed to merge remote version of given or default branch",
}

M.squash = {
  err = "Failed to squash and merge",
  pass = "Squashed and merged successfully",
}

M.merge = {
  err = "Failed to merge and create merge commit",
  pass = "merged with merge commit successfully",
}

M.rebase = {
  err = "Failed to rebase and merge commit to target branch",
  pass = "Rebased and merged successfully to target branch",
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
  err = "Failed to switch to another branch",
  pass = "successfully switch to another branch",
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
  pass = "Pushed %s successfully to remote ...",
}

M.fork = {
  err = "Failed to fork",
  pass = "Forked %s successfully.",
}

M.pr_open = {
  err = "Failed to create a pull request",
  pass = "pull request has been created successfully.",
}

M.pr_info = {
  err = "Failed to get pr info",
}

M.pr_squash = {
  err = "Failed to squash and merge using github-cli",
  pass = "Squashed and merged successfully using github-cli.",
}

M.pr_rebase = {
  err = "Failed to rebase and merge using github-cli",
  pass = "Successfully rebased using github-cli.",
}

M.pr_update = {
  err = "Failed to sync pr info for",
  pass = "PR is synced successfully",
}

M.pr_merge = {
  err = "Failed to merge and create merge commit using github-cli",
  pass = "Successfully merged and rebased with merge commit using github-cli.",
}

M.delete = {
  err = "Fail to delete branch",
  pass = "Branch is deleted successfully",
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

return M
