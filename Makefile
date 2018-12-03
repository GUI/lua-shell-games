.PHONY: \
	all \
	install-test-deps \
	install-test-deps-yum \
	lint \
	release \
	test

all:

lint:
	luacheck .

test: lint
	luarocks make --local shell-games-git-1.rockspec
	busted spec

install-test-deps-yum:
	yum -y install gcc

install-test-deps:
	luarocks install busted 2.0.rc13-0
	luarocks install luacheck 0.22.1-1

release:
	# Ensure the version number has been updated.
	grep -q -F 'VERSION = "${VERSION}"' lib/shell-games.lua
	# Ensure the rockspec has been renamed and updated.
	grep -q -F 'version = "${VERSION}-1"' "shell-games-${VERSION}-1.rockspec"
	grep -q -F 'tag = "v${VERSION}"' "shell-games-${VERSION}-1.rockspec"
	# Ensure the CHANGELOG has been updated.
	grep -q -F '## ${VERSION} -' CHANGELOG.md
	# Make sure tests pass.
	docker-compose run --rm -v "${PWD}:/app" app make test
	# Check for remote tag.
	git ls-remote -t | grep -F "refs/tags/v${VERSION}^{}"
	# Verify LuaRock and OPM can be built locally.
	docker-compose run --rm -v "${PWD}:/app" app luarocks pack "shell-games-${VERSION}-1.rockspec"
	docker-compose run --rm -v "${HOME}/.opmrc:/root/.opmrc" -v "${PWD}:/app" app opm build
	# Upload to LuaRocks and OPM.
	docker-compose run --rm -v "${HOME}/.luarocks/upload_config.lua:/root/.luarocks/upload_config.lua" -v "${PWD}:/app" app luarocks upload "shell-games-${VERSION}-1.rockspec"
	docker-compose run --rm -v "${HOME}/.opmrc:/root/.opmrc" -v "${PWD}:/app" app opm upload
