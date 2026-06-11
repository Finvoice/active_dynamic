$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'active_dynamic'
require 'active_dynamic/migration'

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

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :profiles, force: true do |t|
    t.string :first_name
    t.string :last_name
  end

  CreateActiveDynamicAttributesTable.migrate :up
end

class Profile < ActiveRecord::Base
  has_dynamic_attributes
  validates :first_name, presence: true
end

class ProfileAttributeProvider
  def initialize(model, filtered_value = nil); end

  def call
    [
      ActiveDynamic::AttributeDefinition.new(
        'Life Story',
        datatype: ActiveDynamic::DataType::Text,
        default_value: 'default value for story',
        required: true
      ),
      ActiveDynamic::AttributeDefinition.new('Age', datatype: ActiveDynamic::DataType::Integer),
      ActiveDynamic::AttributeDefinition.new(
        'Please, tell us what is your home town',
        datatype: ActiveDynamic::DataType::Text,
        system_name: 'home_town'
      )
    ]
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }

  # Reset the process-global ActiveDynamic configuration before every example
  # (mirrors the old Minitest #setup) so a `resolve_persisted = true` example
  # cannot leak into the next one.
  config.before do
    ActiveDynamic.configure do |c|
      c.provider_class = ProfileAttributeProvider
      c.resolve_persisted = false
    end
  end

  # Roll back DB writes after each example to keep the in-memory SQLite clean
  # (the old Minitest suite let rows accumulate across tests).
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
