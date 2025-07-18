module RSpec
  module SampleHelper
    module ClassMethods
      def sample(*args)
        args.push({line: caller_locations(1, 1)[0].lineno})
      end
    end

    def self.included(klass)
      klass.extend(ClassMethods)
      # klass.include(RSpec::Rails::FeatureCheck)
    end
  end
end
