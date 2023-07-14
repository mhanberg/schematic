# CHANGELOG

## [0.2.1](https://github.com/mhanberg/schematic/compare/v0.2.0...v0.2.1) (2023-07-14)


### Bug Fixes

* switch opaque to type ([e5591fa](https://github.com/mhanberg/schematic/commit/e5591faf80569d4c33b8b47efa796256dbcde887))

## [0.2.0](https://github.com/mhanberg/schematic/compare/v0.1.1...v0.2.0) (2023-06-22)


### ⚠ BREAKING CHANGES

* comprehensive errors for list schematics ([#26](https://github.com/mhanberg/schematic/issues/26))

### Features

* comprehensive errors for list schematics ([#26](https://github.com/mhanberg/schematic/issues/26)) ([6020981](https://github.com/mhanberg/schematic/commit/602098133f6198b610ab042e07d723fb93b8e648))

## v0.1.1

- fix: specs (#20)
- fix: remove float/1 (#19)

## v0.1.0

- feat: extend maps with map/2 (#18)
- feat: remove null schematic, use literal instead (#17)
- feat: struct schematics (#15)
- feat!: use literal terms as schematics (#14)
- feat: float schematic (#13)

## v0.0.11

* feat: telemetry by @mhanberg in https://github.com/mhanberg/schematic/pull/6

## v0.0.10

- feat: recursive schematics by @mhanberg in https://github.com/mhanberg/schematic/pull/5

## v0.0.9

- feat: allow schemas to correctly dump optional fields

## v0.0.8

- docs

## v0.0.7

- Support Elixir >= v1.10

## v0.0.6

- dump/1 now returns and ok/error tuple
- nullable/1 schematic

## v0.0.5

- fix: handle nil message in oneof schematic

## v0.0.4

- fixed the typespecs

## v0.0.3

- fix: slightly better error message for schemas
- feat: dump
- feat: dispatch to a schematic with a function using oneof
- refactor!: rename assimilate to unify

## v0.0.2

- rename `func` to `raw`
- transform option for `raw` schematic
- `any` schematic
- `tuple` schematic
- `map` schematic can take a `:keys` and `:values` schematic to assimilate any key that matches the schematic

## v0.0.1

Initial Release
