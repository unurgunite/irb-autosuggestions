# frozen_string_literal: true

unless defined?(IRB)
  module IRB
    @conf = {}
    def self.conf
      @conf
    end

    module Color
      def self.colorable?
        false
      end

      def self.colorize_code(code, _complete: true, _ignore_error: false, _colorable: colorable?, _local_variables: [])
        code
      end
    end
  end
end

require 'irb/autosuggestions'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
