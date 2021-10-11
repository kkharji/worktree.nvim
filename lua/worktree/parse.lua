local M = {}

M.has_pr = function(name, cb)
  return function(j, code)
    if code ~= 0 then
      return print "Failed to query open pr from github"
    end
    local res = vim.json.decode(table.concat(j._stdout_results, "\n")).createdBy
    local match = {}

    for _, info in ipairs(res) do
      if info.headRefName == name then
        match = info
        match.name = match.headRefName
        break
      end
      if cb then
        cb(match)
      end
    end
  end
end

M.get_parent = function(name, str)
  str = string.match(str, "].*")
  local lines = vim.split(str, "\n")
  local possible = {}
  for _, line in ipairs(lines) do
    if not string.match(vim.trim(line), "!") and string.match(vim.trim(line), "*") then
      if not string.match(line, name) then
        possible[#possible + 1] = line:match "%[(%S+)]"
      end
    end
  end
  return possible[1]
end

M.repo_parent_dir_name = function(cwd)
  local parts = vim.split(cwd, "/")
  return parts[#parts - 1] .. "/" .. parts[#parts]
end

return M
