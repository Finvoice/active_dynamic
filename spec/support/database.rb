# Boots the in-memory SQLite database the suite runs against and loads the schema:
# a host `profiles` table plus the gem's `active_dynamic_attributes` table.

# Disabled: this logs every SQL statement to STDOUT and floods the spec output.
# Uncomment to inspect the queries the gem emits while debugging a failing example.
# ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

# Active Record Encryption keys for the test env. These derive the real keys at
# runtime, so they only need to be present and stable — any non-empty strings work.
# Distinct values (not one shared "fake-key") so a credential mix-up can't pass silently.
ActiveRecord::Encryption.configure(
  primary_key: 'fake-primary-key',
  deterministic_key: 'fake-deterministic-key',
  key_derivation_salt: 'fake-key-derivation-salt'
)

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :profiles, force: true do |t|
    t.string :first_name
    t.string :last_name
  end

  CreateActiveDynamicAttributesTable.migrate :up
end
