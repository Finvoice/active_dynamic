module ActiveDynamic
  class Attribute < ActiveRecord::Base
    belongs_to :customizable, polymorphic: true

    self.table_name = 'active_dynamic_attributes'
    validates :name, presence: true

    encrypts :sensitive_value

    def resolved_value
      sensitive_value.present? ? sensitive_value : value
    end
  end
end
