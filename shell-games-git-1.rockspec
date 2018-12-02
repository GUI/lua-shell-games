package = "shell-games"
version = "git-1"
source = {
  url = "git://github.com/GUI/lua-shell-games.git",
}
description = {
  summary = "libcidr bindings for Lua",
  detailed = "Perform various CIDR and IP address operations to check IPv4 and IPv6 ranges.",
  homepage = "https://github.com/GUI/lua-shell-games",
  license = "MIT",
}
build = {
  type = "builtin",
  modules = {
    ["shell-games"] = "lib/shell-games.lua",
  },
}
