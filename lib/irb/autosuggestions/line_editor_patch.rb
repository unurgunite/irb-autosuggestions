# frozen_string_literal: true

module Irb
  module Autosuggestions
    # Patches Reline::LineEditor to display fish-like autosuggestions from history.
    module LineEditorPatch
      GRAY = "\e[90m"
      RESET = "\e[0m"
      CONFIG_KEY = :USE_AUTOSUGGESTIONS
      ENV_KEY = 'IRB_AUTOSUGGESTIONS'

      # Intercepts key input to accept autosuggestions on right arrow.
      #
      # @param [Object] key A Reline key event.
      # @return [Object] Returns +super+ for non-right-arrow keys, +nil+ after accept.
      def input_key(key)
        if enabled? && right_arrow?(key)
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

      # Injects ghost text into terminal output after Reline finishes rendering.
      #
      # @private
      # @return [Object] The result of +super+.
      def render(...)
        result = super
        Reline.core.instance_variable_get(:@output).write("\e[J")
        return result unless enabled?

        buffer = whole_buffer
        return result if buffer.empty?

        ghost = ghost_for(buffer)
        return result unless ghost

        render_ghost(ghost)
        result
      end

      # Checks whether autosuggestions are enabled via IRB.conf or env var.
      #
      # @private
      # @return [Boolean]
      def enabled?
        case ENV.fetch(ENV_KEY, nil)
        when '0' then false
        when '1' then true
        else IRB.conf.fetch(CONFIG_KEY, true)
        end
      end

      # Checks if a key event is a right arrow press.
      #
      # @private
      # @param [Object] key A Reline key event.
      # @return [Boolean]
      def right_arrow?(key)
        key.respond_to?(:method_symbol) &&
          key.method_symbol == :ed_next_char
      end

      # Computes the ghost text for a given buffer by finding the matching history entry.
      #
      # @private
      # @param [String] buffer The current whole buffer.
      # @return [String, nil] The remaining text of the suggestion, or nil.
      def ghost_for(buffer)
        suggestion = find_suggestion(buffer)
        return unless suggestion

        ghost = suggestion[buffer.size..]
        return if ghost.nil? || ghost.empty?

        ghost
      end

      # Writes the ghost text (inline + extra lines) to terminal output.
      #
      # @private
      # @param [String] ghost The full ghost text (may contain newlines).
      # @return [void]
      def render_ghost(ghost)
        lines = ghost.split("\n")

        Reline.core.instance_variable_get(:@output).write("#{GRAY}#{lines.first}#{RESET}") unless lines.first.empty?

        write_extra_ghost_lines(lines.drop(1))
        restore_cursor_after(lines)

        Reline.core.instance_variable_get(:@output).flush
      end

      # Writes extra ghost lines below the current buffer line with prompt-width alignment.
      #
      # @private
      # @param [Array<String>] lines Extra ghost lines (excluding the first inline line).
      # @return [void]
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

      # Restores the cursor to the end of the buffer after ghost rendering.
      #
      # @private
      # @param [Array<String>] lines The ghost split into lines.
      # @return [void]
      def restore_cursor_after(lines)
        extra_count = lines.size - 1
        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        pos = prompt_width + (@buffer_of_lines[@line_index] || '').length
        output = Reline.core.instance_variable_get(:@output)

        output.write("\e[#{extra_count}A") if extra_count.positive?
        output.write("\e[0G")
        output.write("\e[#{pos}C")
      end

      # Finds the most recent history entry that starts with the given buffer.
      #
      # @private
      # @param [String] buffer The current whole buffer.
      # @return [String, nil] The matching history entry, or nil.
      def find_suggestion(buffer)
        Reline::HISTORY.reverse.find do |h|
          h != buffer && h.start_with?(buffer)
        end
      end

      # Replaces the entire buffer with the accepted suggestion and triggers a rerender.
      #
      # @private
      # @param [String] suggestion The full multiline suggestion to accept.
      # @return [void]
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
