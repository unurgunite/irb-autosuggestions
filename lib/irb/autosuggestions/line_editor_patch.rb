# frozen_string_literal: true

module Irb
  module Autosuggestions
    # Patches Reline::LineEditor to display fish-like autosuggestions.
    module LineEditorPatch
      RESET = "\e[0m"
      FAINT = "\e[2m"

      # Handles right arrow key to accept the current autosuggestion.
      #
      # @param [Object] key key event from Reline
      # @return [Object]
      def input_key(key)
        return super unless Irb::Autosuggestions.enabled?

        super unless key.respond_to?(:method_symbol) && key.method_symbol == :ed_next_char && process_arrow
      end

      private

      # Overrides Reline render to display ghost text alongside the current buffer.
      #
      # @private
      # @return [Object]
      def render(...)
        return super unless Irb::Autosuggestions.enabled?

        result = super
        clear_old_ghost
        return result if whole_buffer.strip.empty?

        ghost_lines = resolve_ghost
        return result unless ghost_lines

        current_ghost, *extra_lines = ghost_lines
        render_ghost(current_ghost, extra_lines)
        result
      end

      # Clears previously rendered ghost text from the terminal with ANSI escapes.
      #
      # @private
      # @return [void]
      def clear_old_ghost
        output = Reline.core.instance_variable_get(:@output)
        if @autosuggest_ghost_length
          output.write("\e[K")
          @autosuggest_ghost_length = nil
        end
        return unless @autosuggest_extra_count&.positive?

        output.write("\e[s")
        @autosuggest_extra_count.times { output.write("\n\e[K") }
        output.write("\e[#{@autosuggest_extra_count}A\e[u")
        @autosuggest_extra_count = nil
      end

      # Matches the current buffer against history and returns the ghost portion.
      #
      # @private
      # @return [Array<String>, nil]
      def resolve_ghost
        @autosuggest_suggestion = find_suggestion(whole_buffer) if @autosuggest_suggestion.nil?
        if @autosuggest_suggestion &&
           match_suggestion?(whole_buffer, @autosuggest_suggestion) &&
           @autosuggest_suggestion != whole_buffer
          ghost = @autosuggest_suggestion[whole_buffer.size..]
          ghost.lines.map(&:chomp) unless ghost.to_s.empty?
        else
          @autosuggest_suggestion = nil
        end
      end

      # Accepts the remaining suggestion text into the buffer on right arrow.
      #
      # @private
      # @return [Boolean, nil]
      def process_arrow
        suggestion = @autosuggest_suggestion
        return unless suggestion && suggestion != whole_buffer && match_suggestion?(whole_buffer, suggestion)

        remaining = suggestion[whole_buffer.size..]
        return unless remaining && !remaining.empty?

        accept_remaining(@buffer_of_lines[@line_index] || '', remaining)
        @autosuggest_suggestion = nil
        rerender
        true
      end

      # Writes ghost text inline and extra lines below the current terminal line.
      #
      # @private
      # @param [String] current_ghost ghost text for the current line
      # @param [Array<String>] extra_lines ghost lines beyond the current line
      # @return [void]
      def render_ghost(current_ghost, extra_lines)
        output = Reline.core.instance_variable_get(:@output)
        output.write("\e[s")
        unless current_ghost.empty?
          output.write("#{FAINT}#{current_ghost}#{RESET}")
          @autosuggest_ghost_length = current_ghost.length
        end
        write_extra_lines(output, extra_lines)
        output.write("\e[u")
        output.flush
      end

      # Writes extra ghost lines below the current line, aligned to prompt width.
      #
      # @private
      # @param [Object] output terminal output stream
      # @param [Array<String>] lines ghost lines to render
      # @return [void]
      def write_extra_lines(output, lines)
        return unless lines.any?

        pw = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        lines.each do |gl|
          output.write("\n")
          output.write("\e[#{pw}C") if pw.positive?
          output.write("#{FAINT}#{gl}#{RESET}")
        end
        @autosuggest_extra_count = lines.size
      end

      # Searches Reline history for the most recent matching suggestion.
      #
      # @private
      # @param [String] buffer current buffer content
      # @return [String, nil]
      def find_suggestion(buffer)
        Reline::HISTORY.reverse.find do |h|
          h != whole_buffer && match_suggestion?(buffer, h)
        end
      end

      # Checks whether the buffer lines match the suggestion lines positionally.
      #
      # @private
      # @param [String] buffer current buffer content
      # @param [String] suggestion possible suggestion from history
      # @return [Boolean]
      def match_suggestion?(buffer, suggestion)
        buf_lines = buffer.split("\n", -1)
        sug_lines = suggestion.split("\n", -1)
        buf_lines.size <= sug_lines.size &&
          buf_lines.zip(sug_lines).each_with_index.all? do |(b, s), i|
            s && line_matches?(b, s, i == buf_lines.size - 1)
          end
      end

      # Checks if a single buffer line matches a suggestion line (lenient on last).
      #
      # @private
      # @param [String] buf_line a line from the current buffer
      # @param [String] sug_line the corresponding line from the suggestion
      # @param [Boolean] last whether this is the last buffer line
      # @return [Boolean]
      def line_matches?(buf_line, sug_line, last)
        (last && buf_line.strip.empty?) ||
          sug_line.start_with?(buf_line) ||
          (!buf_line.strip.empty? && sug_line.strip.start_with?(buf_line.strip))
      end

      # Applies the remaining suggestion text into the buffer, handling multiline.
      #
      # @private
      # @param [String] buffer current line content
      # @param [String] remaining text from suggestion after the buffer match
      # @return [void]
      def accept_remaining(buffer, remaining)
        if remaining.start_with?("\n")
          remaining = remaining[1..].to_s
          append_lines(remaining.split("\n"))
        else
          lines = remaining.split("\n")
          set_current_line(buffer + lines.first)
          append_lines(lines.drop(1))
        end
      end

      # Inserts multiple lines into the buffer after the current line index.
      #
      # @private
      # @param [Array<String>] lines lines to insert into the buffer
      # @return [Array<String>]
      def append_lines(lines)
        lines.each do |rl|
          @buffer_of_lines.insert(@line_index + 1, rl)
          @line_index += 1
          @byte_pointer = rl.bytesize
        end
      end
    end
  end
end
