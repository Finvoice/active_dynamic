# Boots the in-memory SQLite database the suite runs against and loads the schema:
# a host `profiles` table plus the gem's `active_dynamic_attributes` table.

# Make SQLite behave like the production MySQL schema at the one point the suite breaks.
#
# `save_dynamic_attributes` looks rows up with `find_or_initialize_by(field.as_json)`, which
# relies on every serialized attribute round-tripping exactly. `as_json` serializes times at
# millisecond precision (ActiveSupport's default of 3). In production the
# `active_dynamic_attributes` timestamps are MySQL `datetime` with no sub-second precision
# (`precision: nil`), so the values have no fractional part and the lookup matches. SQLite
# ignores column precision and stores microseconds, so the millisecond `as_json` value misses
# the row, `find_or_initialize_by` builds a *new* record that still carries the original `id`,
# and the follow-up insert blows up with `UNIQUE constraint failed: id`.
#
# Bumping JSON time precision to 6 makes `as_json` lossless against SQLite's microsecond
# storage, reproducing the lossless round-trip MySQL gives us for free. This is a test-env
# workaround only; the real fix (FP-9147) is to look rows up by `name` instead of `as_json`.
ActiveSupport::JSON::Encoding.time_precision = 6

# Disabled: this logs every SQL statement to STDOUT and floods the spec output.
# Uncomment to inspect the queries the gem emits while debugging a failing example.
# ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :profiles, force: true do |t|
    t.string :first_name
    t.string :last_name
  end

  CreateActiveDynamicAttributesTable.migrate :up
end
