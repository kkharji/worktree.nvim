local fmt = {}
local date = require "worktree.date"

---@param branch_name string
---@return string
fmt.into_title = function(branch_name)
  if not branch_name:find "/" then
    return branch_name:gsub("_", " ")
  end
  local parts = vim.split(branch_name, "/")
  local type = parts[1]
  local scope = parts[3] and parts[2] or nil
  local name = vim.trim(scope and parts[3] or parts[2]):gsub("_", " ")
  if scope then
    return string.format("%s(%s): %s", type, scope, name)
  else
    return type .. ": " .. name
  end
end

fmt.into_name = function(str)
  local parts = vim.split(str, ":")
  local title = vim.trim(parts[2])
  local maybe_scope = parts[1]:match "%((%a.*)%)"
  local scope = maybe_scope and maybe_scope .. "/" or ""
  local type = parts[1]:gsub("%((%a.*)%)", "")

  return type .. "/" .. scope .. title:lower():gsub(" ", "_")
end

fmt.to_filename = function(branch_name)
  local as_title = fmt.into_title(branch_name)
  return as_title:gsub(" ", "_"):gsub("%(", ""):gsub("%)", ""):gsub(":", "_")
end

fmt.get_type = function(str)
  return str:match "(%a+)%("
end

fmt.get_scope = function(str)
  return str:match "%a+%((%a+)%)"
end

fmt.get_subject = function(str)
  return str:match "%S+:%s+(%a+.*)"
end
-- I(fmt.get_subject "feat(create): set upstream-push")
local unescape_single_quote = function(v)
  return string.gsub(v, "\\([\\'])", "%1")
end

fmt.parse_branch_info_line = function(line)
  local fields = vim.split(string.sub(line, 2, -2), "''", true)
  local entry = {
    head = fields[1],
    refname = unescape_single_quote(fields[2]),
    upstream = unescape_single_quote(fields[3]),
    since = date.since(fields[4]),
  }

  if entry.upstream == "" then -- we don't want other stuff
    return
  end

  local prefix
  if vim.startswith(entry.refname, "refs/remotes/") then
    prefix = "refs/remotes/"
  elseif vim.startswith(entry.refname, "refs/heads/") then
    prefix = "refs/heads/"
  else
    return
  end

  entry.name = string.sub(entry.refname, string.len(prefix) + 1)
  entry.title = fmt.into_title(entry.name)
  entry.subject = fmt.get_subject(entry.title) or entry.title
  entry.scope = (fmt.get_type(entry.title) or "none") .. "/" .. (fmt.get_scope(entry.title) or "*")
  entry.current = entry.head == "*"

  return entry
end

return fmt
