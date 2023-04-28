# CHANGELOG

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
