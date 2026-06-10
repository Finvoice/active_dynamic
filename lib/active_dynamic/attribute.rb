module ActiveDynamic
  class Attribute < ActiveRecord::Base
    belongs_to :customizable, polymorphic: true

    self.table_name = 'active_dynamic_attributes'
    validates :name, presence: true

    encrypts :encrypted_value

    def resolved_value
      encrypted_value.present? ? encrypted_value : value
    end
  end
end
