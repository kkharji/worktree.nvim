local date = {}

local toseconds = function(seconds)
  local daysDiff = math.floor(seconds / 86400)
  local remainder = (seconds % 86400)
  local hoursDiff = math.floor(remainder / 3600)
  local remainder = (seconds % 3600)
  local minsDiff = math.floor(remainder / 60)
  local secsDiff = (remainder % 60)

  local elapsedTable = { days = daysDiff, hours = hoursDiff, mins = minsDiff, secs = secsDiff }

  return elapsedTable
end

---Return string repersenting the time since a given %Y/%m/%d %H:%M:%S
---@param ymdhms string @%Y/%m/%d %H:%M:%S
date.since = function(ymdhms)
  local parts = vim.split(ymdhms, " ")
  local date = parts[1]
  local time = parts[2]
  local year, month, day = unpack(vim.split(date, "/"))
  local hour, min, sec = unpack(vim.split(time, ":"))

  local timeStamp = os.time {
    month = month,
    day = day,
    year = year,
    hour = hour,
    min = min,
    sec = sec,
    isdst = false,
  }
  local elapsedSeconds = os.time(os.date "!*t") - timeStamp

  local et = toseconds(elapsedSeconds)
  local daysText, hoursText, minsText, secsText

  if et.days == 1 then
    daysText = " day, "
  else
    daysText = " days, "
  end
  if et.hours == 1 then
    hoursText = " hour, "
  else
    hoursText = " hours, "
  end
  if et.mins == 1 then
    minsText = " minute "
  else
    minsText = " minutes "
  end
  if et.secs == 1 then
    secsText = " second "
  else
    secsText = " seconds "
  end

  local outString
  if et.days > 0 then
    outString = et.days .. daysText .. et.hours .. hoursText .. et.mins .. minsText .. "ago"
  elseif et.hours > 0 then
    outString = et.hours .. hoursText .. et.mins .. minsText .. "ago"
  elseif et.mins > 0 then
    outString = et.mins .. minsText .. "ago"
  else
    outString = et.secs .. secsText .. "ago"
  end

  return outString
end

return date
