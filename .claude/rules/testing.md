---
paths:
  - 'spec/**'
---

# Testing Guidelines

RSpec on in-memory SQLite. No Rails, FactoryBot, Sidekiq, or external APIs — those are
consumer-app concerns, not the gem's.

## Structure

- Specs live in `spec/`; mirror the `lib/active_dynamic/` structure as the suite grows
  (e.g. `lib/active_dynamic/attribute.rb` → `spec/active_dynamic/attribute_spec.rb`)
- `spec/spec_helper.rb` owns the harness: SQLite connection, the schema (built from the
  gem's own `CreateActiveDynamicAttributesTable` migration template), and the dummy
  `Profile` model + `ProfileAttributeProvider`
- Exercise dynamic attributes through a model that `has_dynamic_attributes` (e.g. `Profile`)
  driven by a provider — do not insert `ActiveDynamic::Attribute` rows by hand unless the
  test is specifically about that model

## RSpec Conventions

- Use `subject` for the action under test; name it when referenced (`subject(:attribute)`)
- Group `let` blocks at the top; override them in child contexts when values differ
- Only introduce a `let` when reused; inline single-use setup
- Use `context` blocks for scenarios (e.g. "when resolve_persisted is enabled")
- Group multiple expectations in one `it` when they assert the same behavior
- Omit descriptions for self-explanatory examples; use shared examples for common patterns
- Prefer `.to eq(...)` over `.to include(...)`; cover both happy path and edge cases

## Gem-specific Rules

- **Global config is reset per example.** `spec_helper`'s `before` re-applies
  `provider_class` + `resolve_persisted = false`. To test the persisted path, flip
  `resolve_persisted = true` inside a `context`'s own `before` — never leave it set globally.
- **Each example is wrapped in a transaction and rolled back** (`spec_helper`'s `around`).
  Do not rely on rows persisting across examples or on insertion-order ids.
- **`resolve_persisted` matters.** It changes whether `dynamic_attributes` returns
  `AttributeDefinition`s or DB-backed `ActiveDynamic::Attribute`s — test the branch you mean.
- **Do not remove `ActiveSupport::JSON::Encoding.time_precision = 6` in `spec_helper`.** It
  makes SQLite's microsecond timestamps round-trip through `find_or_initialize_by(as_json)`
  the way production MySQL (`datetime` with no sub-second precision) does. The comment there
  explains it; the real fix is to stop looking rows up by `as_json`.
