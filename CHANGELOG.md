# shell-games Change Log

## 1.1.0 - 2019-09-30

### Fixed
- Improve reliability for OpenResty versions prior to 1.15 by eliminating io.popen calls in these older versions (when capturing output, temporary files will be used instead).

## 1.0.2 - 2019-09-29

### Fixed
- Improve reliability when used in OpenResty if OpenResty 1.15 or newer is being used (which eliminates the need for nginx-related signal workarounds).

## 1.0.1 - 2019-05-01

### Fixed
- Fix the `env` option for setting environment variables.

## 1.0.0 - 2018-12-11

### Added
- Initial release.
