module ActiveDynamic
  class NullProvider
    def initialize(model, _filtered_value = nil); end

    def call
      []
    end
  end
end
