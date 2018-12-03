local _M = {
  _VERSION = "1.0.0"
}

local LUA52_MODE = (rawget(math, "mod") == nil)

local RUN_OPTIONS = {
  capture = "boolean",
  chdir = "string",
  env = "table",
  stderr = "string",
  stdout = "string",
  umask = "string",
}

local UNSAFE_CHARS = "[^A-Za-z0-9_@%%+=:,./-]"

local function assert_arg(index, value, expected_type)
  local actual_type = type(value)
  if actual_type ~= expected_type then
    error(string.format("bad argument #%d (%s expected, got %s)", index, expected_type, actual_type), 2)
  end
end

local function assert_run_options(options)
  for key, _ in pairs(options) do
    local expected_type = RUN_OPTIONS[key]
    if not expected_type then
      error(string.format("bad option '%s' (unknown option)", key), 2)
    else
      local actual_type = type(options[key])
      if actual_type ~= expected_type then
        error(string.format("bad option '%s' (%s expected, got %s)", key, expected_type, actual_type), 2)
      end
    end
  end
end

local function add_command_options(command, options)
  if options["env"] ~= nil then
    local env = { "env" }
    for env_key, env_value in pairs(options["env"]) do
      table.insert(env, env_key .. "=" .. env_value)
    end
    command = _M.join(env) .. " && " .. command
  end

  if options["umask"] ~= nil then
    command = _M.join({ "umask", options["umask"] }) .. " && " .. command
  end

  if options["chdir"] ~= nil then
    command = _M.join({ "cd", options["chdir"] }) .. " && " .. command
  end

  if options["stderr"] ~= nil then
    command = command .. " 2>" .. options["stderr"]
  end

  if options["stdout"] ~= nil then
    command = command .. " 1>" .. options["stdout"]
  end

  return command
end

local function capture(command)
  if not LUA52_MODE then
    command = "sh -c " .. _M.quote(command) .. [[; echo -n "=====LUA_SHELL_GAME_STATUS_CODE:$?"]]
  end

  local handle = io.popen(command, "r")

  local all_output
  all_output = handle:read("*a")

  local result = {}
  local err
  if LUA52_MODE then
    local _, _, close_status = handle:close()
    result["status"] = close_status
    result["output"] = all_output
  else
    handle:close()

    local match_output, match_status = string.match(all_output, [[^(.*)=====LUA_SHELL_GAME_STATUS_CODE:(%d+)$]])
    if match_output and match_status then
      result["output"] = match_output
      result["status"] = tonumber(match_status)
    else
      -- This means we never got the "STATUS_CODE" output, so the entire
      -- sub-processes must have gotten killed off.
      err = "Command exited prematurely: " .. command .. "\nOutput: " .. (all_output or "")
    end
  end

  return result, err
end

function _M.quote(str)
  local quoted_str = tostring(str)
  if str == nil or quoted_str == nil or #quoted_str == 0 then
    return "''"
  end

  if not string.match(quoted_str, UNSAFE_CHARS) then
    return quoted_str
  end

  return "'" .. string.gsub(quoted_str, "'", "'\"'\"'") .. "'"
end

function _M.join(args)
  assert_arg(1, args, "table")

  local quoted = {}
  for _, str in ipairs(args) do
    table.insert(quoted, _M.quote(str))
  end

  return table.concat(quoted, " ")
end

function _M.run_raw(command, options)
  assert_arg(1, command, "string")
  if options ~= nil then
    assert_arg(2, options, "table")
  else
    options = {}
  end
  assert_run_options(options)

  command = add_command_options(command, options)

  local result, err
  if options["capture"] then
    result, err = capture(command)
  else
    if LUA52_MODE then
      local _, _, execute_status = os.execute(command)
      result = {
        status = execute_status,
      }
    else
      local execute_status = os.execute(command)
      result = {
        status = (execute_status / 256),
      }
    end
  end
  result["command"] = command

  if err == nil and result["status"] ~= 0 then
    err = "Executing command failed: " .. result["command"]
    if options["capture"] then
      err = err .. "\nOutput: " .. (result["output"] or "")
    end
  end

  return result, err
end

function _M.run(args, options)
  assert_arg(1, args, "table")
  return _M.run_raw(_M.join(args), options)
end

function _M.capture(args, options)
  assert_arg(1, args, "table")
  if options ~= nil then
    assert_arg(2, options, "table")
    if options["capture"] ~= nil then
      error("bad option 'capture' (unknown option)")
    end
  else
    options = {}
  end
  options["capture"] = true

  return _M.run_raw(_M.join(args), options)
end

function _M.capture_combined(args, options)
  assert_arg(1, args, "table")
  if options ~= nil then
    assert_arg(2, options, "table")
    if options["stderr"] ~= nil then
      error("bad option 'stderr' (unknown option)")
    end
  else
    options = {}
  end
  options["stderr"] = "&1"

  return _M.capture(args, options)
end

return _M
