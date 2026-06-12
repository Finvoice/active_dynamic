module ActiveDynamic
  class AttributeDefinition
    attr_reader :display_name, :datatype, :value, :name, :required, :encrypt_value

    def initialize(display_name, params = {})
      options = params.dup
      @name = (options.delete(:system_name) || display_name).parameterize.underscore
      @display_name = display_name
      @datatype = options.delete(:datatype)
      @value = options.delete(:default_value)
      @required = options.delete(:required) || false
      @encrypt_value = ActiveModel::Type::Boolean.new.cast(options.delete(:encrypt_value)) || false

      assign_custom_attributes(options)
    end

    def required?
      !!@required
    end

    private

    # custom attributes from Provider
    def assign_custom_attributes(options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
        self.class.send(:attr_reader, key)
      end
    end
  end
end
