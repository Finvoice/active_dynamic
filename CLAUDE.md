# CLAUDE.md

`active_dynamic` — Ruby gem that attaches dynamic (schema-less) attributes to ActiveRecord
models. A model `include`s the behavior via `has_dynamic_attributes`; a *provider* class
declares which attributes exist, and their values are persisted polymorphically in the
`active_dynamic_attributes` table.

## Ownership

XEN owns this gem. It originated as a fork of `koss-lebedev/active_dynamic`, which is no
longer maintained, so **modify the gem internals directly** — no monkey-patching from
consumer apps. Consumers point at it via git (`github.com/Finvoice/active_dynamic`), not
RubyGems.

## Consumers

`finvoice_underwrite_api` is the primary consumer. It attaches dynamic attributes to
`Deal`, `BusinessOfficer`, `BusinessContact`, and `DynamicObject` (the values for the
dynamic meta-form fields). It runs with `config.resolve_persisted = true`.

## Key Files

| File | Role |
| --- | --- |
| `lib/active_dynamic/has_dynamic_attributes.rb` | The concern models include; holds `dynamic_attributes`, `load_dynamic_attributes`, `save_dynamic_attributes`, and the resolve strategies |
| `lib/active_dynamic/attribute.rb` | `ActiveDynamic::Attribute` — AR model backing the `active_dynamic_attributes` table |
| `lib/active_dynamic/attribute_definition.rb` | Provider-built field metadata (name, datatype, default, required, custom options) |
| `lib/active_dynamic/migration.rb` | Generator template for the `active_dynamic_attributes` table |
| `lib/active_dynamic/configuration.rb` | Global config (`provider_class`, `resolve_persisted`) |

## Core Concepts

- **Provider** — a class set as `ActiveDynamic.configuration.provider_class`; its `#call`
  returns an array of `ActiveDynamic::AttributeDefinition`s for a given model instance.
- **`resolve_persisted`** — when `true`, a persisted record's `dynamic_attributes` combine
  DB rows with provider definitions (`resolve_combined`); when `false`, definitions only.
- **Element type is polymorphic**: `dynamic_attributes` returns `AttributeDefinition`s for a
  new record and `ActiveDynamic::Attribute`s (DB-backed) for a persisted one.

## Commands

```bash
bundle install        # Ruby 3.4.9 (see .ruby-version), bundler from the lockfile
bundle exec rspec     # run the test suite (also `bundle exec rake`)
```

`Gemfile.lock` is intentionally gitignored (library convention); CI resolves fresh.

## Testing

Specs live in `spec/`, run on in-memory SQLite. See `.claude/rules/testing.md` and
`spec/spec_helper.rb` (which documents a deliberate SQLite/MySQL timestamp-precision
workaround). CI (`.github/workflows/test.yml`) runs `rspec` on every push.
