# frozen_string_literal: true

require 'reline'

require_relative 'autosuggestions/version'
require_relative 'autosuggestions/line_editor_patch'

IRB.conf[:USE_AUTOSUGGESTIONS] = ENV.fetch('IRB_USE_AUTOSUGGESTIONS', 'true') != 'false' if defined?(IRB)

module Irb
  # Fish-like autosuggestions for the Reline editor used by IRB.
  module Autosuggestions
    class << self
      # @return [Boolean]
      def enabled?
        return @enabled unless @enabled.nil?

        defined?(IRB) ? IRB.conf[:USE_AUTOSUGGESTIONS] : true
      end

      attr_writer :enabled
    end
  end
end

Reline::LineEditor.prepend(Irb::Autosuggestions::LineEditorPatch)
