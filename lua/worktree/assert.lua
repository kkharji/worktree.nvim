local assert = {}
local Job = require "plenary.job"

assert.is_online = function(as_job)
  local check = { "ping", "-c", "1", "github.com" }
  if not as_job then
    check.sync = true
    local _, code = Job(check)
    return code == 0
  end
  return Job:new(check)
end

return assert
