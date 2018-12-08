describe("run", function()
  local shell = require "shell-games"
  local clean_spec_tmp = require "spec/support/clean_spec_tmp"
  local table_keys = require "spec/support/table_keys"

  before_each(function()
    clean_spec_tmp()
  end)

  it("returns status, but no output by default", function()
    local result, err = shell.run_raw("echo -n foo")
    assert.are.same({
      command = "echo -n foo",
      status = 0,
    }, result)
    assert.are.equal(nil, err)
  end)

  it("capture option", function()
    local result, err = shell.run_raw("echo -n foo", { capture = true })
    assert.are.same({
      command = "echo -n foo",
      status = 0,
      output = "foo",
    }, result)
    assert.are.equal(nil, err)

    result, err = shell.run_raw("echo -n foo", { capture = false })
    assert.are.same({
      command = "echo -n foo",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run_raw("echo -n foo", { capture = "true" })
    end, "bad option 'capture' (boolean expected, got string)")
  end)

  it("chdir option", function()
    local file = io.open("spec/tmp/run_raw chdir.txt", "w")
    file:write("")
    file:close()

    local result, err = shell.run_raw("ls -1 'run_raw chdir.txt'")
    assert.are.same({
      command = "ls -1 'run_raw chdir.txt'",
      status = 2,
    }, result)
    assert.are.equal("Executing command failed (exit code 2): ls -1 'run_raw chdir.txt'", err)

    result, err = shell.run_raw("ls -1 'run_raw chdir.txt'", { chdir = "spec/tmp" })
    assert.are.same({
      command = "cd spec/tmp && ls -1 'run_raw chdir.txt'",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run_raw("ls -1 'chdir.txt'", { chdir = 1 })
    end, "bad option 'chdir' (string expected, got number)")
  end)

  it("env option", function()
    local result, err = shell.run_raw("env", { capture = true })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("env", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH=/", result["output"])
    assert.are_not.match("SHELL_GAMES_FOO=foo", result["output"])
    assert.are.equal(nil, err)

    result, err = shell.run_raw("env", { capture = true, env = { SHELL_GAMES_FOO = "foo bar" } })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("env 'SHELL_GAMES_FOO=foo bar' && env", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH=/", result["output"])
    assert.are.match("SHELL_GAMES_FOO=foo bar", result["output"])
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run_raw("env", { env = "FOO=bar" })
    end, "bad option 'env' (table expected, got string)")
  end)

  it("stderr option", function()
    local result, err = shell.run_raw("spec/support/generate-stdout-stderr", { stderr = "spec/tmp/run_raw stderr.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2> 'spec/tmp/run_raw stderr.txt'",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run_raw stderr.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("2. stderr\n4. stderr\n", file_output)

    assert.has.error(function()
      shell.run_raw("spec/support/generate-stdout-stderr", { stderr = 1 })
    end, "bad option 'stderr' (string expected, got number)")
  end)

  it("stdout option", function()
    local result, err = shell.run_raw("spec/support/generate-stdout-stderr", { stdout = "spec/tmp/run_raw stdout.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 1> 'spec/tmp/run_raw stdout.txt'",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run_raw stdout.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n3. stdout\n", file_output)

    assert.has.error(function()
      shell.run_raw("spec/support/generate-stdout-stderr", { stdout = 1 })
    end, "bad option 'stdout' (string expected, got number)")
  end)

  it("stdout redirect to stderr", function()
    local result, err = shell.run_raw("spec/support/generate-stdout-stderr", { stdout = "&2", stderr = "spec/tmp/run_raw stdout-to-stderr.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2> 'spec/tmp/run_raw stdout-to-stderr.txt' 1>&2",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run_raw stdout-to-stderr.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n2. stderr\n3. stdout\n4. stderr\n", file_output)
  end)

  it("stderr redirect to stdout", function()
    local result, err = shell.run_raw("spec/support/generate-stdout-stderr", { stderr = "&1", stdout = "spec/tmp/run_raw stderr-to-stdout.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>&1 1> 'spec/tmp/run_raw stderr-to-stdout.txt'",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run_raw stderr-to-stdout.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n3. stdout\n", file_output)
  end)

  it("umask option", function()
    local result, err = shell.run_raw("umask", { capture = true })
    assert.are.same({
      command = "umask",
      status = 0,
      output = "0022\n",
    }, result)
    assert.are.equal(nil, err)

    result, err = shell.run_raw("umask", { capture = true, umask = "077" })
    assert.are.same({
      command = "umask 077 && umask",
      status = 0,
      output = "0077\n",
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run_raw("umask", { umask = 077 })
    end, "bad option 'umask' (string expected, got number)")
  end)

  it("allows for unquoted arguments", function()
    local result, err = shell.run_raw("echo -n \"PATH: $PATH\"", { capture = true })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("echo -n \"PATH: $PATH\"", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH: /", result["output"])
    assert.are.equal(nil, err)
  end)

  it("arguments can be quoted", function()
    local result, err = shell.run_raw("echo -n 'PATH: $PATH'", { capture = true })
    assert.are.same({
      command = "echo -n 'PATH: $PATH'",
      status = 0,
      output = "PATH: $PATH",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("returns command errors", function()
    local result, err = shell.run_raw("exit 33")
    assert.are.same({
      command = "exit 33",
      status = 33,
    }, result)
    assert.are.equal("Executing command failed (exit code 33): exit 33", err)
  end)

  it("raises error when string not given for command", function()
    assert.has.error(function()
      shell.run_raw(nil)
    end, "bad argument #1 (string expected, got nil)")

    assert.has.error(function()
      shell.run_raw({ "ls" })
    end, "bad argument #1 (string expected, got table)")
  end)

  it("raises error when table not given for options", function()
    assert.has.error(function()
      shell.run_raw("ls", "options")
    end, "bad argument #2 (table expected, got string)")
  end)

  it("raises error for unknown option", function()
    assert.has.error(function()
      shell.run_raw("ls", { foobar = true })
    end, "bad option 'foobar' (unknown option)")
  end)
end)
