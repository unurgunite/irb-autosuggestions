# frozen_string_literal: true

module Irb
  module Autosuggestions
    module LineEditorPatch
      GRAY = "\e[90m"
      RESET = "\e[0m"

      def input_key(key)
        if right_arrow?(key)
          buffer = whole_buffer
          suggestion = find_suggestion(buffer)

          if suggestion && suggestion != buffer
            accept_suggestion(suggestion)
            return
          end
        end

        super
      end

      private

      def render(...)
        result = super
        output = Reline.core.instance_variable_get(:@output)
        output.write("\e[K")

        buffer = whole_buffer
        return result if buffer.empty?

        suggestion = find_suggestion(buffer)
        return result unless suggestion

        ghost = suggestion[buffer.size..]
        return result if ghost.nil? || ghost.empty?

        lines = ghost.split("\n")
        current_ghost = lines.first
        extra_lines = lines.drop(1)

        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0

        output.write("#{GRAY}#{current_ghost}#{RESET}") unless current_ghost.empty?

        extra_lines.each do |line|
          output.write("\n\e[K")
          output.write("\e[#{prompt_width}C") if prompt_width.positive?
          output.write("#{GRAY}#{line}#{RESET}")
        end

        output.write("\e[#{extra_lines.size}A") if extra_lines.size.positive?
        output.write("\e[0G")
        output.write("\e[#{prompt_width + (@buffer_of_lines[@line_index] || '').length}C")

        output.flush
        result
      end

      def right_arrow?(key)
        key.respond_to?(:method_symbol) &&
          key.method_symbol == :ed_next_char
      end

      def find_suggestion(buffer)
        Reline::HISTORY.reverse.find do |h|
          h != buffer && h.start_with?(buffer)
        end
      end

      def accept_suggestion(suggestion)
        sug_lines = suggestion.split("\n")
        @buffer_of_lines = sug_lines
        @line_index = sug_lines.size - 1
        @byte_pointer = sug_lines.last.bytesize
        rerender
      end
    end
  end
end
