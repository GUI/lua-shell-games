describe("run", function()
  local shell = require "shell-games"
  local clean_spec_tmp = require "spec/support/clean_spec_tmp"
  local table_keys = require "spec/support/table_keys"

  before_each(function()
    clean_spec_tmp()
  end)

  it("returns status, but no output by default", function()
    local result, err = shell.run({ "echo", "-n", "foo" })
    assert.are.same({
      command = "echo -n foo",
      status = 0,
    }, result)
    assert.are.equal(nil, err)
  end)

  it("capture option", function()
    local result, err = shell.run({ "echo", "-n", "foo" }, { capture = true })
    assert.are.same({
      command = "echo -n foo",
      status = 0,
      output = "foo",
    }, result)
    assert.are.equal(nil, err)

    result, err = shell.run({ "echo", "-n", "foo" }, { capture = false })
    assert.are.same({
      command = "echo -n foo",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run({ "echo", "-n", "foo" }, { capture = "true" })
    end, "bad run option 'capture' (boolean expected, got string)")
  end)

  it("chdir option", function()
    local file = io.open("spec/tmp/run-chdir.txt", "w")
    file:write("")
    file:close()

    local result, err = shell.run({ "ls", "-1", "run-chdir.txt" })
    assert.are.same({
      command = "ls -1 run-chdir.txt",
      status = 2,
    }, result)
    assert.are.equal("Executing command failed: ls -1 run-chdir.txt", err)

    result, err = shell.run({ "ls", "-1", "run-chdir.txt" }, { chdir = "spec/tmp" })
    assert.are.same({
      command = "cd spec/tmp && ls -1 run-chdir.txt",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run({ "ls", "-1", "run-chdir.txt" }, { chdir = 1 })
    end, "bad run option 'chdir' (string expected, got number)")
  end)

  it("env option", function()
    local result, err = shell.run({ "env" }, { capture = true })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("env", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH=/", result["output"])
    assert.are_not.match("SHELL_GAMES_FOO=foo", result["output"])
    assert.are.equal(nil, err)

    result, err = shell.run({ "env" }, { capture = true, env = { SHELL_GAMES_FOO = "foo bar" } })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("env 'SHELL_GAMES_FOO=foo bar' && env", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH=/", result["output"])
    assert.are.match("SHELL_GAMES_FOO=foo bar", result["output"])
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run({ "env" }, { env = "FOO=bar" })
    end, "bad run option 'env' (table expected, got string)")
  end)

  it("stderr option", function()
    local result, err = shell.run({ "spec/support/generate-stdout-stderr" }, { stderr = "spec/tmp/run-stderr.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>spec/tmp/run-stderr.txt",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run-stderr.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("2. stderr\n4. stderr\n", file_output)

    assert.has.error(function()
      shell.run({ "spec/support/generate-stdout-stderr" }, { stderr = 1 })
    end, "bad run option 'stderr' (string expected, got number)")
  end)

  it("stdout option", function()
    local result, err = shell.run({ "spec/support/generate-stdout-stderr" }, { stdout = "spec/tmp/run-stdout.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 1>spec/tmp/run-stdout.txt",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run-stdout.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n3. stdout\n", file_output)

    assert.has.error(function()
      shell.run({ "spec/support/generate-stdout-stderr" }, { stdout = 1 })
    end, "bad run option 'stdout' (string expected, got number)")
  end)

  it("stdout redirect to stderr", function()
    local result, err = shell.run({ "spec/support/generate-stdout-stderr" }, { stdout = "&2", stderr = "spec/tmp/run-stdout-to-stderr.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>spec/tmp/run-stdout-to-stderr.txt 1>&2",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run-stdout-to-stderr.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n2. stderr\n3. stdout\n4. stderr\n", file_output)
  end)

  it("stderr redirect to stdout", function()
    local result, err = shell.run({ "spec/support/generate-stdout-stderr" }, { stderr = "&1", stdout = "spec/tmp/run-stderr-to-stdout.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>&1 1>spec/tmp/run-stderr-to-stdout.txt",
      status = 0,
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/run-stderr-to-stdout.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n3. stdout\n", file_output)
  end)

  it("umask option", function()
    local result, err = shell.run({ "umask" }, { capture = true })
    assert.are.same({
      command = "umask",
      status = 0,
      output = "0022\n",
    }, result)
    assert.are.equal(nil, err)

    result, err = shell.run({ "umask" }, { capture = true, umask = "077" })
    assert.are.same({
      command = "umask 077 && umask",
      status = 0,
      output = "0077\n",
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.run({ "umask" }, { umask = 077 })
    end, "bad run option 'umask' (string expected, got number)")
  end)

  it("quotes arguments", function()
    local result, err = shell.run({ "echo", "-n", "$PATH" }, { capture = true })
    assert.are.same({
      command = "echo -n '$PATH'",
      status = 0,
      output = "$PATH",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("returns command errors", function()
    local result, err = shell.run({ "exit", "33" })
    assert.are.same({
      command = "exit 33",
      status = 33,
    }, result)
    assert.are.equal("Executing command failed: exit 33", err)
  end)

  it("raises error when table not given for args", function()
    assert.has.error(function()
      shell.run(nil)
    end, "bad argument #1 (table expected, got nil)")

    assert.has.error(function()
      shell.run("ls")
    end, "bad argument #1 (table expected, got string)")
  end)

  it("raises error when table not given for options", function()
    assert.has.error(function()
      shell.run({ "ls" }, "options")
    end, "bad argument #2 (table expected, got string)")
  end)
end)
