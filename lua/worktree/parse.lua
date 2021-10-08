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

return M
