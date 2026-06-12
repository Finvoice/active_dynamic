# The test domain the suite exercises: a host model that mixes in the gem, plus the
# attribute provider that feeds it dynamic field definitions. Edit these to add or
# change the dynamic fields the examples rely on.

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
