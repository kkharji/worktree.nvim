local chglog = {}

function chglog.template()
  local cwd = vim.loop.cwd()
  local filename = "prchangelog.md"
  local opts = {}
  opts[#opts + 1] = cwd .. "/.github/chglog/" .. filename
  opts[#opts + 1] = cwd .. "/.chglog/" .. filename
  opts[#opts + 1] = vim.fn.stdpath "config" .. "/" .. filename
  local path

  for _, opt in ipairs(opts) do
    if vim.loop.fs_stat(opt) then
      path = opt
      break
    end
  end
  if not path then
    error "couldn't find git chglog template "
  end
  return path
end

local function chglog.config()
  local cwd = vim.loop.cwd()
  local filename = "prchangelog.md"
  local opts = {}
  opts[#opts + 1] = cwd .. "/.github/chglog/" .. filename
  opts[#opts + 1] = cwd .. "/.chglog/" .. filename
  opts[#opts + 1] = vim.fn.stdpath "config" .. "/" .. filename
  local path

  for _, opt in ipairs(opts) do
    if vim.loop.fs_stat(opt) then
      path = opt
      break
    end
  end
  if not path then
    error "couldn't find git chglog template "
  end
  return path
end

I(get_git_chglog_template())
