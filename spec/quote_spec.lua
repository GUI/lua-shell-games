-- Quoting implementation and tests based on Python's shlex:
-- https://github.com/python/cpython/blob/v3.7.1/Lib/test/test_shlex.py#L296-L309
describe("quote", function()
  local shell = require "shell-games"

  it("quotes empty string", function()
    assert.are.equal("''", shell.quote(""))
  end)

  it("quotes nil as empty string", function()
    assert.are.equal("''", shell.quote(nil))
  end)

  it("returns false as string", function()
    assert.are.equal("false", shell.quote(false))
  end)

  it("returns number as string", function()
    assert.are.equal("3", shell.quote(3))
  end)

  it("returns other object types as strings", function()
    assert.are.match("'table: 0x%w+'", shell.quote({ foo = "bar" }))
  end)

  it("returns safe strings as-is", function()
    local safe = {
      "foobar",
      [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@%_-+=:,./]],
    }
    for _, str in ipairs(safe) do
      assert.are.equal(str, shell.quote(str))
    end
  end)

  it("quotes string with spaces", function()
    assert.are.equal("'test file name'", shell.quote("test file name"))
  end)

  it("quotes string with double quotes", function()
    assert.are.equal([['"foo bar"']], shell.quote([["foo bar"]]))
  end)

  it("quotes unsafe strings", function()
    local unsafe = {
      [["]],
      [[`]],
      [[$]],
      [[\]],
      [[!]],
      "\233",
      "\224",
      "\223",
      [[&]],
      [[;]],
      [[{]],
      [[}]],
    }
    for _, str in ipairs(unsafe) do
      print(str)
      assert.are.equal(string.format([['test%sname']], str), shell.quote("test" .. str .. "name"))
      assert.are.equal(string.format([['test%s'"'"'name'"'"'']], str), shell.quote("test" .. str .. "'name'"))
    end
  end)
end)
