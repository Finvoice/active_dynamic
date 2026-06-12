module ActiveDynamic
  class Attribute < ActiveRecord::Base
    # Transient, non-persisted flag. Set from the ActiveDynamic::AttributeDefinition /
    # provider (MetaField#encrypt_value) so the write path knows whether to encrypt.
    attr_writer :encrypt_value

    belongs_to :customizable, polymorphic: true

    self.table_name = 'active_dynamic_attributes'

    validates :name, presence: true

    encrypts :encrypted_value

    # Whether the value must be stored encrypted: either flagged by the field
    # definition (transient, set from the provider) or the row already stores
    # an encrypted value — a row never silently downgrades to plaintext.
    def encrypt_value
      @encrypt_value || !encrypted_value.nil?
    end

    # Reads resolve transparently to the encrypted column, falling back to the
    # plaintext column only when no encrypted value was ever stored (nil) — an
    # empty string is a real stored value. Callers just use #value.
    def value
      encrypted_value.nil? ? super : encrypted_value
    end

    # Routes a raw value to the right column, clearing the other one so a field
    # never holds both a plaintext and an encrypted value.
    def assign_value(raw_value)
      if encrypt_value
        assign_attributes(encrypted_value: raw_value, value: nil)
      else
        assign_attributes(value: raw_value, encrypted_value: nil)
      end
    end
  end
end
