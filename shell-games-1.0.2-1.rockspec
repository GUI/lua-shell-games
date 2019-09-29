package = "shell-games"
version = "1.0.2-1"
source = {
  url = "git://github.com/GUI/lua-shell-games.git",
  tag = "v1.0.2"
}
description = {
  summary = "A library to help execute shell commands more easily and safely.",
  detailed = "Execute shell commands while capturing their output and exit codes. Includes helpers for performing shell escaping/quoting.",
  homepage = "https://github.com/GUI/lua-shell-games",
  license = "MIT",
}
build = {
  type = "builtin",
  modules = {
    ["shell-games"] = "lib/shell-games.lua",
  },
}
