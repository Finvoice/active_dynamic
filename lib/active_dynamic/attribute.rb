module ActiveDynamic
  class Attribute < ActiveRecord::Base
    belongs_to :customizable, polymorphic: true

    self.table_name = 'active_dynamic_attributes'
    validates :name, presence: true

    encrypts :encrypted_value

    # Transient, non-persisted flag. Set from the AttributeDefinition / provider
    # (MetaField#encrypt_value) so the write path knows whether to encrypt.
    attr_accessor :encrypt_value

    # Reads resolve transparently to the encrypted column when present,
    # falling back to the plaintext column otherwise. Callers just use #value.
    def value
      encrypted_value.presence || super
    end
  end
end
