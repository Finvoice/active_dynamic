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

    # Defers a given `value:` until after the other attributes — notably the
    # transient encrypt_value flag — so the routing in #value= cannot depend on
    # hash-key order. Also covers construction (AR's initialize delegates here).
    # Records loaded from the database do not pass through here (AR instantiates
    # them via init_with), so existing plaintext rows are read as-is.
    def assign_attributes(attributes)
      attributes = attributes.to_h.symbolize_keys if attributes
      has_value = attributes&.key?(:value)
      raw_value = attributes&.delete(:value)
      super
      self.value = raw_value if has_value
    end

    # Routes a write to the right column, clearing the other one so a field
    # never holds both a plaintext and an encrypted value.
    def value=(raw_value)
      if encrypt_value
        self.encrypted_value = raw_value
        super(nil)
      else
        super
        self.encrypted_value = nil
      end
    end
  end
end
