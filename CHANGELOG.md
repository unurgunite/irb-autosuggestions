# Changelog

## [0.2.3] - 2026-08-21

### Fixed

- Text duplication and stale ghost fragments when typing lines that wrap past the terminal edge; ghost preview is now
  hidden for suggestions that do not fit the current row instead of corrupting the display
- Dim/color state leaking into subsequent input after accepting a suggestion

## [0.2.2] - 2026-07-08

### Added

- Alternative key bindings to accept ghost suggestion: Tab, Ctrl+F, Ctrl+E (configurable via
  `IRB.conf[:AUTOSUGGESTION_ACCEPT_KEYS]`) ([#15], [#157])
- Configurable ghost color/style via `IRB.conf[:AUTOSUGGESTION_GHOST_COLOR]` (ANSI string) and
  `IRB.conf[:AUTOSUGGESTION_GHOST_STYLE]` (declarative hash) ([#16], [#163])
- GitHub issue templates (bug report, feature request) and pull request template

### Fixed

- Ghost text artifacts and cursor misalignment after accepting multiline (10+ lines) suggestions ([#19], [#256])
- Auto-execute guard — verified Enter always fires exactly once regardless of ghost visibility ([#18], [#159])

## [0.2.1] - 2026-07-05

### Fixed

- Ruby 4.0 compatibility: arrow (`ed_next_char`) not erasing after suggestion accept ([#13])

## [0.2.0] - 2026-06-30

### Added

- Syntax-colored ghost text via `IRB::Color.colorize_code` (dimmed)
- Prefix-filtered history navigation (up/down arrows match typed prefix)
- Ruby 2.7 support

### Changed

- Ghost text now uses dim syntax colors when `IRB.conf[:USE_COLORIZE]` is enabled

## [0.1.1] - 2026-06-25

### Added

- `IRB.conf[:USE_AUTOSUGGESTIONS]` toggle
- Environment variable `IRB_AUTOSUGGESTIONS` override
- RBS type signatures

### Fixed

- Gem metadata (licenses, homepage)

## [0.1.0] - 2026-06-20

### Added

- Initial release: fish-like autosuggestions from `Reline::HISTORY`
- Right arrow key accepts ghost suggestion
- Gray ghost text (`\e[90m`)
- Configuration via `IRB.conf[:USE_AUTOSUGGESTIONS]`

[#15]: https://github.com/unurgunite/irb-autosuggestions/pull/15

[#16]: https://github.com/unurgunite/irb-autosuggestions/pull/16

[#18]: https://github.com/unurgunite/irb-autosuggestions/pull/18

[#19]: https://github.com/unurgunite/irb-autosuggestions/pull/19

[#157]: https://github.com/unurgunite/irb-autosuggestions/issues/157

[#163]: https://github.com/unurgunite/irb-autosuggestions/issues/163

[#159]: https://github.com/unurgunite/irb-autosuggestions/issues/159

[#256]: https://github.com/unurgunite/irb-autosuggestions/issues/256
