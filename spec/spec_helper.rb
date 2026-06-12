$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'active_dynamic'
require 'active_dynamic/migration'

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
