local util = {}

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

----TODO: return a function that accept definition of messages
--- TODO: use notify.nvim
util.notify = function(msgs)
  return function(job_type, ...)
    local group = msgs[job_type]
    local args = { ... }
    return vim.schedule_wrap(function(j, code)
      if code ~= 0 and group[1] then
        args[#args + 1] = I(vim.inspect(j:stderr_result(), "\n"))
        vim.api.nvim_echo({ { tostr(group[1], unpack(args)), "WarningMsg" } }, true, {})
      elseif group[2] then
        vim.api.nvim_echo({ { tostr(group[2], unpack(args)), "healthSuccess" } }, true, {})
      end
    end)
  end
end

return util
