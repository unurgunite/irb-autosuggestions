# frozen_string_literal: true

module Irb
  module Autosuggestions
    # Patches Reline::LineEditor to display fish-like autosuggestions from history.
    module LineEditorPatch
      GRAY = "\e[90m"
      RESET = "\e[0m"

      # Method documentation.
      #
      # @param [Object] key Param documentation.
      # @return [Object]
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

      # Method documentation.
      #
      # @private
      # @return [Object]
      def render(...)
        result = super
        Reline.core.instance_variable_get(:@output).write("\e[J")

        ghost = ghost_for(whole_buffer)
        return result unless ghost

        render_ghost(ghost)
        result
      end

      # Method documentation.
      #
      # @private
      # @param [Object] key Param documentation.
      # @return [Object]
      def right_arrow?(key)
        key.respond_to?(:method_symbol) &&
          key.method_symbol == :ed_next_char
      end

      # Method documentation.
      #
      # @private
      # @param [Object] buffer Param documentation.
      # @return [Object]
      def ghost_for(buffer)
        suggestion = find_suggestion(buffer)
        return unless suggestion

        ghost = suggestion[buffer.size..]
        return if ghost.nil? || ghost.empty?

        ghost
      end

      # Method documentation.
      #
      # @private
      # @param [Object] ghost Param documentation.
      # @return [void]
      def render_ghost(ghost)
        lines = ghost.split("\n")

        Reline.core.instance_variable_get(:@output).write("#{GRAY}#{lines.first}#{RESET}") unless lines.first.empty?

        write_extra_ghost_lines(lines.drop(1))
        restore_cursor_after(lines)

        Reline.core.instance_variable_get(:@output).flush
      end

      # Method documentation.
      #
      # @private
      # @param [Object] lines Param documentation.
      # @return [Object]
      def write_extra_ghost_lines(lines)
        return if lines.empty?

        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        output = Reline.core.instance_variable_get(:@output)

        lines.each do |line|
          output.write("\n\e[K")
          output.write("\e[#{prompt_width}C") if prompt_width.positive?
          output.write("#{GRAY}#{line}#{RESET}")
        end
      end

      # Method documentation.
      #
      # @private
      # @param [Object] lines Param documentation.
      # @return [Object]
      def restore_cursor_after(lines)
        extra_count = lines.size - 1
        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        pos = prompt_width + (@buffer_of_lines[@line_index] || '').length
        output = Reline.core.instance_variable_get(:@output)

        output.write("\e[#{extra_count}A") if extra_count.positive?
        output.write("\e[0G")
        output.write("\e[#{pos}C")
      end

      # Method documentation.
      #
      # @private
      # @param [String] buffer Param documentation.
      # @return [String, nil]
      def find_suggestion(buffer)
        Reline::HISTORY.reverse.find do |h|
          h != buffer && h.start_with?(buffer)
        end
      end

      # Method documentation.
      #
      # @private
      # @param [Object] suggestion Param documentation.
      # @return [Object]
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
