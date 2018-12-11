describe("lua mode", function()
  it("is running the expected lua version", function()
    assert.are.equal(os.getenv("EXPECTED_LUA_VERSION"), _VERSION)
  end)

  it("is running the expected luajit version", function()
    if os.getenv("EXPECTED_LUAJIT_VERSION") then
      assert.are.equal(os.getenv("EXPECTED_LUAJIT_VERSION"), string.sub(jit.version, 0, 10)) -- luacheck: globals jit
    else
      assert.are.equal(nil, jit) -- luacheck: globals jit
    end
  end)

  it("openresty is present if expected", function()
    if os.getenv("ASSERT_NGX") == "true" then
      assert.are.equal("table", type(ngx)) -- luacheck: globals ngx
    else
      assert.are.equal(nil, ngx) -- luacheck: globals ngx
    end
  end)

  it("os.execute behavior", function()
    local ok, status, code = os.execute("echo foo")
    if os.getenv("REFUTE_LUA52_BEHAVIOR") == "true" then
      assert.are.equal(0, ok)
      assert.are.equal(nil, status)
      assert.are.equal(nil, code)
    else
      assert.are.equal(true, ok)
      assert.are.equal("exit", status)
      assert.are.equal(0, code)
    end

    ok, status, code = os.execute("exit 9")
    if os.getenv("REFUTE_LUA52_BEHAVIOR") == "true" then
      assert.are.equal(9 * 256, ok)
      assert.are.equal(nil, status)
      assert.are.equal(nil, code)
    else
      assert.are.equal(nil, ok)
      assert.are.equal("exit", status)
      assert.are.equal(9, code)
    end
  end)

  it("io.popen behavior", function()
    local handle = io.popen("echo foo", "r")
    handle:read("*a")
    local ok, status, code = handle:close()
    -- io.popen's normal behavior (when not wrapped by shell-games) under
    -- OpenResty can be erratic, since sometimes it returns normally, and other
    -- times it returns an unsuccessful exit code:
    -- https://github.com/openresty/lua-nginx-module/issues/779
    if os.getenv("ASSERT_NGX") == "true" and ok == nil then
      assert.are.equal(nil, ok)
      assert.are.equal("No child processes", status)
      assert.are.equal(10, code)
    elseif os.getenv("REFUTE_LUA52_BEHAVIOR") == "true" then
      assert.are.equal(true, ok)
      assert.are.equal(nil, status)
      assert.are.equal(nil, code)
    else
      assert.are.equal(true, ok)
      assert.are.equal("exit", status)
      assert.are.equal(0, code)
    end

    handle = io.popen("exit 9", "r")
    ok, status, code = handle:close()
    if os.getenv("REFUTE_LUA52_BEHAVIOR") == "true" then
      assert.are.equal(true, ok)
      assert.are.equal(nil, status)
      assert.are.equal(nil, code)
    else
      assert.are.equal(nil, ok)
      assert.are.equal("exit", status)
      assert.are.equal(9, code)
    end
  end)
end)
