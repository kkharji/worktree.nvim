return function(o)
  local job = require("plenary.job"):new(o)
  if o.sync then
    return job:sync()
  end
  return job
end
