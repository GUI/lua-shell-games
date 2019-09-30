local _M = {
  _VERSION = "1.1.0"
}

-- Valid options for the `run` commands.
local RUN_OPTIONS = {
  capture = "boolean",
  chdir = "string",
  env = "table",
  stderr = "string",
  stdout = "string",
  umask = "string",
}

-- Detect whether the app is running in Lua 5.2 mode (including LuaJIT compiled
-- with the LUAJIT_ENABLE_LUA52COMPAT option), since that affects the
-- os.execute and pipe:close return codes.
--
-- Based on https://github.com/keplerproject/lua-compat-5.3/blob/v0.7/compat53/init.lua#L88-L91
local lua_version = _VERSION:sub(-3)
local is_luajit = (string.dump(function() end) or ""):sub(1, 3) == "\027LJ"
local is_luajit52 = is_luajit and #setmetatable({}, { __len = function() return 1 end }) == 1
local LUA52_MODE = lua_version > "5.1" or is_luajit52

-- Detect when the OpenResty version is < v1.15 (ngx_lua < v0.10.14). For these
-- older versions, io.popen is unstable due to nginx's SIGCHLD handler. So for
-- these versions, only ever use os.execute and capture output by writing it to
-- a temporary file.
--
-- OpenResty 1.15+ (ngx_lua 0.10.14+) should behave properly as long as the
-- "lua_sa_restart" option is left enabled (the default).
--
-- https://github.com/openresty/lua-nginx-module/issues/779
-- https://github.com/openresty/resty-cli/issues/35
-- https://github.com/openresty/lua-nginx-module/pull/1296
local NGX_UNSTABLE_POPEN = (ngx and ngx.config.ngx_lua_version < 10014) -- luacheck: globals ngx

-- Characters that need shell escaping.
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

-- Alter the command line string to execute, depending on the run options
-- passed in. This allows for changing the command in common ways (eg, to set
-- environment variables, change the directory, or redirect output).
local function add_command_options(command, options)
  if options["env"] ~= nil then
    local env = { "env" }
    for env_key, env_value in pairs(options["env"]) do
      table.insert(env, env_key .. "=" .. env_value)
    end
    command = _M.join(env) .. " " .. command
  end

  if options["umask"] ~= nil then
    command = _M.join({ "umask", options["umask"] }) .. " && " .. command
  end

  if options["chdir"] ~= nil then
    command = _M.join({ "cd", options["chdir"] }) .. " && " .. command
  end

  if options["stderr"] ~= nil or options["stdout"] ~= nil then
    -- If we're attempting to redirect stderr/stdout and the command consists
    -- of multiple commands (either separated by "&&" or ";"), then wrap the
    -- entire command in a sub-shell. This is needed so that we capture the
    -- entire output, rather than just the output for the last command.
    if string.match(command, "&&") or string.match(command, ";") then
      if not string.match(command, "^sh -c ") then
        command = "sh -c " .. _M.quote(command)
      end
    end

    -- Redirect stderr. If a path is given, be sure to escape it, but if a
    -- we're just redirecting to another descriptor (eg, stdout, &1), then
    -- don't escape.
    if options["stderr"] ~= nil then
      if string.match(options["stderr"], "^&%d+$") then
        command = command .. " 2>" .. options["stderr"]
      else
        command = command .. " 2> " .. _M.quote(options["stderr"])
      end
    end

    if options["stdout"] ~= nil then
      if string.match(options["stdout"], "^&%d+$") then
        command = command .. " 1>" .. options["stdout"]
      else
        command = command .. " 1> " .. _M.quote(options["stdout"])
      end
    end
  end

  return command
end

local function execute(command)
  local result

  if LUA52_MODE then
    local _, _, status = os.execute(command)
    result = {
      status = status,
    }
  else
    -- os.execute's return signature is a bit different under Lua 5.1 or older.
    -- The exit code value is also shifted by one byte in Linux, so it needs to
    -- be adjusted:
    -- http://lua-users.org/lists/lua-l/2004-10/msg00109.html
    -- https://github.com/keplerproject/lua-compat-5.3/pull/17
    -- https://github.com/keplerproject/lua-compat-5.3/blob/v0.7/compat53/module.lua#L604-L606
    local status = os.execute(command)
    if string.sub(package.config, 1, 1) == "/" then
      status = status / 256
    end
    result = {
      status = status,
    }
  end

  return result
end

local function capture(command)
  local tmp_output_path

  -- By default we'll try to get the exit code from io.popen's handle:close()
  -- behavior. However, this functionality is only available in Lua 5.2+. So
  -- for Lua 5.1 and older, fallback to a workaround approach which consists of
  -- appending the status code to the shell output, and then parsing that out
  -- (http://lua-users.org/lists/lua-l/2009-06/msg00133.html).
  local status_code_workaround = false
  if not LUA52_MODE and not NGX_UNSTABLE_POPEN then
    status_code_workaround = true
  end

  if status_code_workaround or NGX_UNSTABLE_POPEN then
    -- Ensure that the command is wrapped in sub-shell, so we should always
    -- output the status code output afterwards, even if the underlying command
    -- exits early. This sub shell also ensures we properly handle the output
    -- redirection when outputting to a temp file.
    if not string.match(command, "^sh -c ") then
      command = "sh -c " .. _M.quote(command)
    end

    if status_code_workaround then
      command = command .. [[; echo -n "=====LUA_SHELL_GAME_STATUS_CODE:$?"]]
    elseif NGX_UNSTABLE_POPEN then
      -- For OpenResty < 1.15, capture output to a file to deal with unstable
      -- "popen" issues.
      tmp_output_path = os.tmpname()
      command = command .. " > " .. _M.quote(tmp_output_path)
    end
  end

  local result = {}
  local err
  local handle
  if NGX_UNSTABLE_POPEN then
    result, err = execute(command)
    handle = io.open(tmp_output_path, "r")
  else
    handle = io.popen(command, "r")
  end
  local all_output = handle:read("*a")

  if not status_code_workaround then
    if NGX_UNSTABLE_POPEN then
      os.remove(tmp_output_path)
    else
      local _, _, close_status = handle:close()
      result["status"] = close_status
    end

    result["output"] = all_output
  else
    handle:close()

    -- Parse the status code out of the output.
    if all_output then
      local match_output, match_status = string.match(all_output, [[^(.*)=====LUA_SHELL_GAME_STATUS_CODE:(%d+)$]])
      if match_output and match_status then
        result["output"] = match_output
        result["status"] = tonumber(match_status)
      end
    end

    if result["status"] == nil then
      -- This means we never got the "STATUS_CODE" output, so the entire
      -- sub-processes must have gotten killed off.
      err = "Command exited prematurely: " .. command .. "\nOutput: " .. (all_output or "")
    end
  end

  return result, err
end

-- Quoting implementation based on Python's shlex:
-- https://github.com/python/cpython/blob/v3.7.1/Lib/shlex.py#L310-L319
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
    result, err = execute(command)
  end
  result["command"] = command

  if err == nil and result["status"] ~= 0 then
    err = "Executing command failed (exit code " .. (result["status"] or "") .. "): " .. result["command"]
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
