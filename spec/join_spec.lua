describe("join", function()
  local shell = require "shell-games"

  it("joins safe arguments", function()
    assert.are.equal("ls -l /tmp", shell.join({ "ls", "-l", "/tmp" }))
  end)

  it("joins and quotes unsafe arguments", function()
    assert.are.equal("ls -l '/tmp/foo bar'", shell.join({ "ls", "-l", "/tmp/foo bar" }))
  end)

  it("returns empty table as empty string", function()
    assert.are.equal("", shell.join({}))
  end)

  it("raises error when table not given", function()
    assert.has.error(function()
      shell.join(nil)
    end, "bad argument #1 (table expected, got nil)")

    assert.has.error(function()
      shell.join("test")
    end, "bad argument #1 (table expected, got string)")
  end)
end)
