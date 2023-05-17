module ActiveDynamic
  module ActiveRecord

    def has_dynamic_attributes
      include ActiveDynamic::HasDynamicAttributes
    end

    def has_dynamic_attributes_using_object_type
      @filter_column = 'object_type'
      include ActiveDynamic::HasDynamicAttributes
    end

  end
end

ActiveRecord::Base.extend ActiveDynamic::ActiveRecord
