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
        clear_extra_ghost
        result = super

        buffer = whole_buffer
        return result if buffer.empty?

        suggestion = find_suggestion(buffer)
        return result unless suggestion

        ghost = suggestion[buffer.size..]
        return result if ghost.nil? || ghost.empty?

        lines = ghost.split("\n")
        current_ghost = lines.first
        extra_lines = lines.drop(1)

        output = Reline.core.instance_variable_get(:@output)

        if current_ghost.empty?
          if extra_lines.any?
            output.write("\e[s")
            extra_lines.each do |line|
              output.write("\n#{GRAY}#{line}#{RESET}")
            end
            @autosuggest_extra_count = extra_lines.size
            output.write("\e[u")
          end
        else
          output.write("#{GRAY}#{current_ghost}#{RESET}")
          output.write("\e[#{current_ghost.length}D")

          if extra_lines.any?
            output.write("\e[s")
            extra_lines.each do |line|
              output.write("\n#{GRAY}#{line}#{RESET}")
            end
            @autosuggest_extra_count = extra_lines.size
            output.write("\e[u")
          end
        end

        output.flush
        result
      end

      def clear_extra_ghost
        return unless @autosuggest_extra_count&.positive?

        output = Reline.core.instance_variable_get(:@output)
        output.write("\e[s")
        @autosuggest_extra_count.times { output.write("\n\e[K") }
        output.write("\e[#{@autosuggest_extra_count}A\e[u")
        @autosuggest_extra_count = nil
      end

      def accept_suggestion(suggestion)
        sug_lines = suggestion.split("\n")
        set_current_line(sug_lines.first)
        sug_lines.drop(1).each do |line|
          @buffer_of_lines.insert(@line_index + 1, line)
          @line_index += 1
        end
        @byte_pointer = sug_lines.last.bytesize
        rerender
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
    end
  end
end
