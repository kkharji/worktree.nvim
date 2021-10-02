local fmt = {}

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

return fmt
