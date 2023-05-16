module ActiveDynamic
  module ActiveRecord

    def has_dynamic_attributes(evaluation_field: nil)
      @evaluation_field = evaluation_field
      include ActiveDynamic::HasDynamicAttributes
    end

  end
end

ActiveRecord::Base.extend ActiveDynamic::ActiveRecord
