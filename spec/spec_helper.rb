$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'active_dynamic'
require 'active_dynamic/migration'

# Baseline test environment shared by every spec: the in-memory database and schema.
# Test-specific setup (the Profile model, its provider, and the provider config hook)
# is required by the spec files that use it, not loaded globally here.
require_relative 'support/database'

RSpec.configure do |config|
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }

  # Roll back DB writes after each example to keep the in-memory SQLite clean
  # (the old Minitest suite let rows accumulate across tests).
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
