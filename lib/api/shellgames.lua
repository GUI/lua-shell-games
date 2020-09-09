-- luacheck: no unused
-- luacheck: no max line length
-- luacheck: no global

---@class ShellGamesRunOptions
local ShellGamesRunOptions = {
  --- Whether or not to capture the command's output.
  capture = false,
  --- Change the current working directory to this path before executing the command.
  chdir = "",
  --- Set environment variables before executing the command.
  --- Accepts a table of environment variable names and values.
  env = {},
  --- Redirect the command's stderr output to a different path.
  stderr = "",
  --- Redirect the command's stdout output to a different path.
  stdout = "",
  --- Change the process's umask before executing the command.
  umask = ""
}

---@class ShellGamesRunResult
local ShellGamesRunResult = {
  --- A string that shows the full command that was executed,
  --- after taking into account escaping and the options.
  command = "",
  --- The exit code of the command.
  status = 0,
  --- This field is only present if the `capture` option was enabled.
  --- If capturing was enabled, then this reflects the output of the command.
  --- By default, this will only contains the stdout from the command, and not the stderr.
  output = ""
}

--- @class ShellGames
local shell = {}

--- Execute a shell command.
--- ```lua
--- local result, err = shell.run({ "ls", "-l", "/tmp" })
--- ```
---@param command table|string
---@param options ShellGamesRunOptions
shell.run = function (command, options)
  local result ---@type ShellGamesRunResult
  local err = ""
  return result, err
end

--- Execute a shell command, capturing stdout as a string.
--- ```lua
--- local result, err = shell.capture({ "ls", "-l", "/tmp" })
--- ```
---@param command table|string
---@param options ShellGamesRunOptions
shell.capture = function(command, options)
  local result ---@type ShellGamesRunResult
  local err = ""
  return result, err
end

--- Execute a shell command, capturing both stdout and stderr as a single string.
--- ```lua
--- local result, err = shell.capture_combined({ "ls", "-l", "/tmp/non-existent" })
--- ```
---@param command table|string
---@param options ShellGamesRunOptions
shell.capture_combined = function(command, options)
  local result ---@type ShellGamesRunResult
  local err = ""
  return result, err
end

--- Execute a shell command given as a raw string.
--- ```lua
--- local result, err = shell.run_raw("echo $PATH", {capture = true})
--- print(result.output)
--- ```
---@param command string
---@param options ShellGamesRunOptions
shell.run_raw = function(command, options)
  local result ---@type ShellGamesRunResult
  local err = ""
  return result, err
end

--- Return a shell-escaped version of the string.
--- The escaped string can safely be used as one token in a shell command.
--- ```lua
--- shell.quote("ls") -- "ls"
--- shell.quote("It's happening.") -- [['It'"'"'s happening.']]
--- shell.quote("$PATH") -- "'$PATH'"
--- ```
---@param str string
shell.quote = function(str)
  return str
end

--- Accepts a table of individual command arguments,
--- which will be escaped and joined together by spaces.
--- Suitable for turning a list of command arguments into a single command string.
--- ```lua
--- shell.join({ "ls", "-l", "/tmp/foo bar" }) -- "ls -l '/tmp/foo bar'"
--- ```
---@param strings table
shell.join = function(strings)
  return ""
end

return shell
