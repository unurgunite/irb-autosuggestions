# frozen_string_literal: true

unless defined?(IRB)
  module IRB
    # stub for Ruby 4.0
    @conf = {}
    def self.conf
      @conf
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
