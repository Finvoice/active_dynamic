module ActiveDynamic
  module HasDynamicAttributes
    extend ActiveSupport::Concern

    included do
      has_many :active_dynamic_attributes,
               class_name: 'ActiveDynamic::Attribute',
               autosave: true,
               dependent: :destroy,
               as: :customizable
      before_save :save_dynamic_attributes
    end

    class_methods do
      def where_dynamic(options)
        query = joins(:active_dynamic_attributes)

        options.each { |prop, value| query = query.where(active_dynamic_attributes: { name: prop, value: }) }

        query
      end
    end

    def dynamic_attributes
      if persisted? && any_dynamic_attributes?
        should_resolve_persisted? ? resolve_combined : resolve_from_db
      else
        resolve_from_provider
      end
    end

    def dynamic_attributes_loaded?
      @dynamic_attributes_loaded ||= false
    end

    def respond_to?(method_name, include_private = false)
      if super
        true
      else
        load_dynamic_attributes unless dynamic_attributes_loaded?
        dynamic_attributes.find { |attr| attr.name == method_name.to_s.delete('=') }.present?
      end
    end

    def method_missing(method_name, *, &)
      if dynamic_attributes_loaded?
        super
      else
        load_dynamic_attributes
        send(method_name, *, &)
      end
    end

    # The dynamic accessors are singleton methods, which `dup`/`clone` do not copy —
    # but the instance variables tracking the loaded state are copied. Reset them so
    # the copy lazily resolves its own accessors instead of raising NoMethodError.
    def initialize_dup(other)
      super
      @dynamic_attributes_loaded = false
      @_custom_fields = nil
    end

    private

    def should_resolve_persisted?
      value = ActiveDynamic.configuration.resolve_persisted
      case value
      when TrueClass, FalseClass
        value
      when Proc
        value.call(self)
      else
        raise "Invalid configuration for resolve_persisted. Value should be Bool or Proc, got #{value.class}"
      end
    end

    def any_dynamic_attributes?
      active_dynamic_attributes.any?
    end

    # Returns the union of the record's persisted attributes and the provider's
    # current attribute definitions, with persisted rows taking precedence when a
    # name exists in both. The provider-defined fields that are not yet persisted
    # are returned as plain in-memory ActiveDynamic::Attribute instances.
    # They only reach the database when the record is saved through `save_dynamic_attributes`
    # and a value has been set for them.
    def resolve_combined
      persisted = resolve_from_db
      persisted_names = persisted.to_set(&:name)
      attribute_definitions = resolve_from_provider

      # Stamp the definition's current encryption flag onto the persisted rows so
      # that updating a value after its field is flagged re-routes it to the
      # encrypted column (see ActiveDynamic::Attribute#value=).
      definitions_by_name = attribute_definitions.index_by(&:name)
      persisted.each { |attribute| attribute.encrypt_value = definitions_by_name[attribute.name]&.encrypt_value }

      provider_only = attribute_definitions
                      .reject { |attribute_definition| persisted_names.include?(attribute_definition.name) }
                      .map { |attribute_definition| build_attribute(attribute_definition) }

      persisted + provider_only
    end

    def build_attribute(attribute_definition)
      ActiveDynamic::Attribute.new(
        customizable: self,
        name: attribute_definition.name,
        display_name: attribute_definition.display_name,
        datatype: attribute_definition.datatype,
        value: attribute_definition.value,
        required: attribute_definition.required?,
        encrypt_value: attribute_definition.encrypt_value
      )
    end

    def resolve_from_db
      active_dynamic_attributes
    end

    def resolve_from_provider
      filtered_value = nil
      filtered_value = object_type if has_attribute?(:object_type)
      ActiveDynamic.configuration.provider_class.new(self, filtered_value).call
    end

    def generate_accessors(fields)
      fields.each do |field|
        add_presence_validator(field.name) if field.required?

        define_singleton_method(field.name) { _custom_fields[field.name] }

        define_singleton_method("#{field.name}=") { |value| _custom_fields[field.name] = value && value.to_s.strip }
      end
    end

    def add_presence_validator(attribute)
      singleton_class.instance_eval { validates_presence_of(attribute) }
    end

    def _custom_fields
      @_custom_fields ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    def load_dynamic_attributes
      dynamic_attributes.each { |field| _custom_fields[field.name] = field.value }

      generate_accessors dynamic_attributes
      @dynamic_attributes_loaded = true
    end

    def save_dynamic_attributes
      # `field` is polymorphic, depending on the parent's state (see #dynamic_attributes):
      #   - new record .................. ActiveDynamic::AttributeDefinition (from the provider)
      #   - persisted, no rows yet ...... ActiveDynamic::AttributeDefinition (from the provider)
      #   - persisted, has rows ......... ActiveDynamic::Attribute (DB rows, plus provider-built
      #                                   ones when resolve_persisted is enabled)
      dynamic_attributes.each do |field|
        # A key exists in _custom_fields only once the accessors were loaded; no
        # key means the dynamic attributes were never touched on this instance.
        next unless _custom_fields.key?(field.name)

        save_dynamic_attribute(field, _custom_fields[field.name])
      end
    end

    def save_dynamic_attribute(field, field_value)
      # nil clears an existing row but must never materialize a new one — and
      # find_or_initialize_by appends the built record to the association, so
      # the check has to happen before it.
      return if field_value.nil? && active_dynamic_attributes.none? { |attribute| attribute.name == field.name }

      attr = active_dynamic_attributes.find_or_initialize_by(name: field.name)
      if attr.new_record?
        attr.assign_attributes(display_name: field.display_name, datatype: field.datatype, required: field.required?)
      end
      attr.encrypt_value = field.encrypt_value
      attr.value = field_value
      attr.save if persisted?
    end
  end
end
