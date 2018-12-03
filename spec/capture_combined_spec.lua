describe("capture_combined", function()
  local shell = require "shell-games"
  local clean_spec_tmp = require "spec/support/clean_spec_tmp"
  local table_keys = require "spec/support/table_keys"

  before_each(function()
    clean_spec_tmp()
  end)

  it("captures output by default", function()
    local result, err = shell.capture_combined({ "echo", "-n", "foo" })
    assert.are.same({
      command = "echo -n foo 2>&1",
      status = 0,
      output = "foo",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("captures multi-line output", function()
    local result, err = shell.capture_combined({ "echo", "foo\nbar\nhello\nworld!" })
    assert.are.same({
      command = "echo 'foo\nbar\nhello\nworld!' 2>&1",
      status = 0,
      output = "foo\nbar\nhello\nworld!\n",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("captures mixed stdout and stderr by default", function()
    local result, err = shell.capture_combined({ "spec/support/generate-stdout-stderr" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>&1",
      status = 0,
      output = "1. stdout\n2. stderr\n3. stdout\n4. stderr\n",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("capture option is invalid", function()
    assert.has.error(function()
      shell.capture_combined({ "echo", "-n", "foo" }, { capture = true })
    end, "bad option 'capture' (unknown option)")
  end)

  it("chdir option", function()
    local file = io.open("spec/tmp/capture_combined-chdir.txt", "w")
    file:write("")
    file:close()

    local result, err = shell.capture_combined({ "ls", "-1", "capture_combined-chdir.txt" })
    assert.are.same({
      command = "ls -1 capture_combined-chdir.txt 2>&1",
      status = 2,
      output = "ls: cannot access capture_combined-chdir.txt: No such file or directory\n"
    }, result)
    assert.are.equal("Executing command failed: ls -1 capture_combined-chdir.txt 2>&1\nOutput: ls: cannot access capture_combined-chdir.txt: No such file or directory\n", err)

    result, err = shell.capture_combined({ "ls", "-1", "capture_combined-chdir.txt" }, { chdir = "spec/tmp" })
    assert.are.same({
      command = "cd spec/tmp && ls -1 capture_combined-chdir.txt 2>&1",
      status = 0,
      output = "capture_combined-chdir.txt\n",
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.capture_combined({ "ls", "-1", "run-chdir.txt" }, { chdir = 1 })
    end, "bad option 'chdir' (string expected, got number)")
  end)

  it("env option", function()
    local result, err = shell.capture_combined({ "env" })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("env 2>&1", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH=/", result["output"])
    assert.are_not.match("SHELL_GAMES_FOO=foo", result["output"])
    assert.are.equal(nil, err)

    result, err = shell.capture_combined({ "env" }, { env = { SHELL_GAMES_FOO = "foo bar" } })
    assert.are.same({ "command", "output", "status" }, table_keys(result))
    assert.are.equal("env 'SHELL_GAMES_FOO=foo bar' && env 2>&1", result["command"])
    assert.are.equal(0, result["status"])
    assert.are.match("PATH=/", result["output"])
    assert.are.match("SHELL_GAMES_FOO=foo bar", result["output"])
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.capture_combined({ "env" }, { env = "FOO=bar" })
    end, "bad option 'env' (table expected, got string)")
  end)

  it("stderr option is invalid", function()
    assert.has.error(function()
      shell.capture_combined({ "spec/support/generate-stdout-stderr" }, { stderr = "spec/tmp/capture_combined-stderr.txt" })
    end, "bad option 'stderr' (unknown option)")
  end)

  it("stdout option", function()
    local result, err = shell.capture_combined({ "spec/support/generate-stdout-stderr" }, { stdout = "spec/tmp/capture_combined-stdout.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>&1 1>spec/tmp/capture_combined-stdout.txt",
      status = 0,
      output = "2. stderr\n4. stderr\n",
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/capture_combined-stdout.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n3. stdout\n", file_output)

    assert.has.error(function()
      shell.capture_combined({ "spec/support/generate-stdout-stderr" }, { stdout = 1 })
    end, "bad option 'stdout' (string expected, got number)")
  end)

  it("stdout redirect to stderr", function()
    local result, err = shell.capture_combined({ "spec/support/generate-stdout-stderr" }, { stdout = "&2" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>&1 1>&2",
      status = 0,
      output = "1. stdout\n2. stderr\n3. stdout\n4. stderr\n",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("stderr redirect to stdout", function()
    local result, err = shell.capture_combined({ "spec/support/generate-stdout-stderr" }, { stdout = "spec/tmp/capture_combined-stderr-to-stdout.txt" })
    assert.are.same({
      command = "spec/support/generate-stdout-stderr 2>&1 1>spec/tmp/capture_combined-stderr-to-stdout.txt",
      status = 0,
      output = "2. stderr\n4. stderr\n",
    }, result)
    assert.are.equal(nil, err)

    local file = io.open("spec/tmp/capture_combined-stderr-to-stdout.txt")
    local file_output = file:read("*a")
    file:close()
    assert.are.equal("1. stdout\n3. stdout\n", file_output)
  end)

  it("umask option", function()
    local result, err = shell.capture_combined({ "umask" })
    assert.are.same({
      command = "umask 2>&1",
      status = 0,
      output = "0022\n",
    }, result)
    assert.are.equal(nil, err)

    result, err = shell.capture_combined({ "umask" }, { umask = "077" })
    assert.are.same({
      command = "umask 077 && umask 2>&1",
      status = 0,
      output = "0077\n",
    }, result)
    assert.are.equal(nil, err)

    assert.has.error(function()
      shell.capture_combined({ "umask" }, { umask = 077 })
    end, "bad option 'umask' (string expected, got number)")
  end)

  it("quotes arguments", function()
    local result, err = shell.capture_combined({ "echo", "-n", "$PATH" })
    assert.are.same({
      command = "echo -n '$PATH' 2>&1",
      status = 0,
      output = "$PATH",
    }, result)
    assert.are.equal(nil, err)
  end)

  it("returns command errors", function()
    local result, err = shell.capture_combined({ "exit", "33" })
    assert.are.same({
      command = "exit 33 2>&1",
      status = 33,
      output = "",
    }, result)
    assert.are.equal("Executing command failed: exit 33 2>&1\nOutput: ", err)
  end)

  it("raises error when table not given for args", function()
    assert.has.error(function()
      shell.capture_combined(nil)
    end, "bad argument #1 (table expected, got nil)")

    assert.has.error(function()
      shell.capture_combined("ls")
    end, "bad argument #1 (table expected, got string)")
  end)

  it("raises error when table not given for options", function()
    assert.has.error(function()
      shell.capture_combined({ "ls" }, "options")
    end, "bad argument #2 (table expected, got string)")
  end)

  it("raises error for unknown option", function()
    assert.has.error(function()
      shell.capture_combined({ "ls" }, { foobar = true })
    end, "bad option 'foobar' (unknown option)")
  end)
end)
