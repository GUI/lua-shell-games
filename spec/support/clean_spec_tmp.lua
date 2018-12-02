local shell = require "shell-games"

return function()
  local _, rm_err = shell.capture_combined({ "rm", "-rf", "spec/tmp" })
  if rm_err then
    error("Failed to remove spec/tmp: " .. rm_err)
  end

  local _, mkdir_err = shell.capture_combined({ "mkdir", "-p", "spec/tmp" })
  if mkdir_err then
    error("Failed to create spec/tmp: " .. mkdir_err)
  end
end
