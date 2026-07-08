# frozen_string_literal: true

module Irb
  module Autosuggestions
    # Patches Reline::LineEditor to display fish-like autosuggestions from history.
    # rubocop:disable Metrics/ModuleLength, SortedMethodsByCall/Waterfall
    module LineEditorPatch
      GRAY = "\e[90m"
      DIM = "\e[2m"
      RESET_COLOR = "\e[39;49m"
      RESET = "\e[0m"
      FG_COLORS = ((30..37).to_a + (90..97).to_a + [38, 39]).freeze
      CONFIG_KEY = :USE_AUTOSUGGESTIONS
      ENV_KEY = 'IRB_AUTOSUGGESTIONS'
      CONFIG_NAV_KEY = :USE_PREFIX_HISTORY_NAVIGATION
      ENV_NAV_KEY = 'IRB_PREFIX_HISTORY_NAVIGATION'
      ACCEPT_KEYS_CONFIG = :AUTOSUGGESTION_ACCEPT_KEYS
      DEFAULT_ACCEPT_KEYS = %i[ed_next_char ed_end_of_line tab].freeze

      # Intercepts key input to accept autosuggestions on configured keys
      # and clears the prefix navigation anchor on non-history keys.
      #
      # @param [Object] key A Reline key event.
      # @return [Object]
      def input_key(key)
        clear_prefix_anchor if navigation_enabled? && !history_navigation_key?(key)

        if enabled? && accept_key?(key)
          buffer = whole_buffer
          suggestion = find_suggestion(buffer)

          if suggestion && suggestion != buffer
            accept_suggestion(suggestion)
            return
          end
        end

        super
      end

      # Injects ghost text into terminal output after Reline finishes rendering.
      # Must be public because Reline::Core calls +rerender+ externally.
      # Works on both Reline 0.3.x (rerender is the main rendering entry) and
      # Reline 0.4+ (rerender calls render internally).
      #
      # @return [Object] The result of +super+.
      def rerender
        result = super
        if enabled?
          clear_previous_ghost
          render_ghost_suggestion
        end
        result
      end

      private

      # Prefix-filtered up-arrow history navigation.
      #
      # @private
      # @param [Object] key
      # @param [Integer] arg Repeat count.
      # @return [Object]
      def ed_prev_history(key, arg: 1)
        if navigation_enabled? && (@line_index.zero? || @history_pointer)
          buffer = prefix_buffer_for_nav
          if buffer && !buffer.empty?
            walk_history_back(buffer, arg)
            return
          end
        end
        clear_prefix_anchor
        super
      end

      # Prefix-filtered down-arrow history navigation.
      #
      # @private
      # @param [Object] key
      # @param [Integer] arg Repeat count.
      # @return [Object]
      def ed_next_history(key, arg: 1)
        if navigation_enabled? && @history_pointer && @prefix_buffer
          walk_history_forward(arg)
          return
        end
        clear_prefix_anchor
        super
      end

      # Returns the anchor buffer for prefix navigation: the frozen prefix
      # during an ongoing session, +whole_buffer+ on the first press from
      # base buffer, or +nil+ when nothing was typed.
      #
      # @private
      # @return [String, nil]
      def prefix_buffer_for_nav
        return @prefix_buffer if @prefix_buffer

        whole_buffer unless @history_pointer
      end

      # Checks if a key event triggers history navigation (up/down arrow).
      #
      # @private
      # @param [Object] key A Reline key event.
      # @return [Boolean]
      def history_navigation_key?(key)
        key.respond_to?(:method_symbol) &&
          %i[ed_prev_history ed_next_history].include?(key.method_symbol)
      end

      # Clears ghost from the previous frame: inline text from buffer end
      # to end of line, and each extra line below. Restores cursor column
      # afterwards so Reline's cursor tracking is not disturbed.
      #
      # @private
      # @return [void]
      def clear_previous_ghost
        clear_inline_ghost
        return unless @ghost_line_count&.positive?

        origin_column = cursor_column_at_byte_pointer
        output = Reline.core.instance_variable_get(:@output)
        @ghost_line_count.times { output.write("\e[1B\e[2K") }
        output.write("\e[#{@ghost_line_count}A")
        output.write("\e[0G\e[#{origin_column}C")
      end

      # Clears inline ghost text from the buffer end to end of line.
      #
      # @private
      # @return [void]
      def clear_inline_ghost
        return unless @has_inline_ghost

        output = Reline.core.instance_variable_get(:@output)
        buf_end = move_to_buffer_end
        origin_column = cursor_column_at_byte_pointer
        output.write("#{buf_end}\e[K")
        output.write("\e[0G\e[#{origin_column}C")
        @has_inline_ghost = false
      end

      # Walks backward through history, loading each matching entry.
      #
      # @private
      # @param [String] buffer The prefix anchor.
      # @param [Integer] arg Repeat count.
      # @return [Object]
      def walk_history_back(buffer, arg)
        arg.times do
          pointer = find_prev_match(buffer, @history_pointer)
          break unless pointer

          move_history(pointer, line: :end, cursor: :end)
          @prefix_buffer = buffer
        end
      end

      # Walks forward through history. Returns to base when exhausted.
      #
      # @private
      # @param [Integer] arg Repeat count.
      # @return [Object]
      def walk_history_forward(arg)
        arg.times do
          pointer = find_next_match(@prefix_buffer, @history_pointer)
          if pointer
            move_history(pointer, line: :start, cursor: :end)
          else
            move_history(Reline::HISTORY.size, line: :start, cursor: :end)
            break
          end
        end
      end

      # Removes the prefix anchor so the next up/down starts fresh.
      #
      # @private
      # @return [void]
      def clear_prefix_anchor
        return unless instance_variable_defined?(:@prefix_buffer)

        remove_instance_variable(:@prefix_buffer)
      end

      # Whether prefix-filtered history navigation is enabled.
      # Falls back to the value of +enabled?+ when not explicitly set.
      #
      # @private
      # @return [Boolean]
      def navigation_enabled?
        case ENV.fetch(ENV_NAV_KEY, nil)
        when '0' then false
        when '1' then true
        else
          val = IRB.conf[CONFIG_NAV_KEY]
          val.nil? ? enabled? : val
        end
      end

      # Checks whether autosuggestions are enabled via IRB.conf or env var.
      #
      # @private
      # @return [Boolean]
      def enabled?
        case ENV.fetch(ENV_KEY, nil)
        when '0' then false
        when '1' then true
        else
          val = IRB.conf[CONFIG_KEY]
          val.nil? || val
        end
      end

      # Checks if a key event matches any configured accept key.
      # Defaults to right arrow (:ed_next_char).
      # Tab is matched specially — method_symbol == :ed_insert + char == "\t".
      #
      # @private
      # @param [Object] key A Reline key event.
      # @return [Boolean]
      def accept_key?(key)
        accept_keys = IRB.conf.fetch(ACCEPT_KEYS_CONFIG, DEFAULT_ACCEPT_KEYS)
        accept_keys.any? { |k| key_match?(key, k) }
      end

      # Checks if a key matches a given config symbol.
      #
      # @private
      # @param [Object] key A Reline key event.
      # @param [Symbol] config_symbol One of :ed_next_char, :ed_end_of_line, :tab, etc.
      # @return [Boolean]
      def key_match?(key, config_symbol)
        return false unless key.respond_to?(:method_symbol)

        if config_symbol == :tab
          key.method_symbol == :ed_insert &&
            key.respond_to?(:char) &&
            key.char == "\t"
        else
          key.method_symbol == config_symbol
        end
      end

      # Finds the index of the previous (older) history entry starting with +buffer+.
      #
      # @private
      # @param [String] buffer Search prefix.
      # @param [Integer, nil] from_pointer Current history pointer (nil = base buffer).
      # @return [Integer, nil]
      def find_prev_match(buffer, from_pointer)
        start_idx = (from_pointer || Reline::HISTORY.size) - 1
        return nil if start_idx.negative?

        start_idx.downto(0) do |i|
          entry = Reline::HISTORY[i]
          next if entry.nil? || (dedup?(buffer) && duplicate_of_newer?(i, entry))

          return i if entry.start_with?(buffer)
        end
        nil
      end

      # Finds the index of the next (newer) history entry starting with +buffer+.
      #
      # @private
      # @param [String] buffer Search prefix.
      # @param [Integer, nil] from_pointer Current history pointer.
      # @return [Integer, nil]
      def find_next_match(buffer, from_pointer) # rubocop:disable Metrics/CyclomaticComplexity
        return nil unless from_pointer

        start_idx = from_pointer + 1
        return nil if start_idx > Reline::HISTORY.size - 1

        (start_idx...Reline::HISTORY.size).each do |i|
          entry = Reline::HISTORY[i]
          next if entry.nil? || (dedup?(buffer) && duplicate_of_newer?(i, entry))

          return i if entry.start_with?(buffer)
        end
        nil
      end

      # Whether duplicate collapsing is active (only for prefix search).
      #
      # @private
      # @param [String] buffer Search prefix.
      # @return [Boolean]
      def dedup?(buffer)
        !buffer.empty?
      end

      # Whether +entry+ at index +idx+ is a consecutive duplicate of the next entry.
      #
      # @private
      # @param [Integer] idx
      # @param [String] entry
      # @return [Boolean]
      def duplicate_of_newer?(idx, entry)
        idx < Reline::HISTORY.size - 1 && entry == Reline::HISTORY[idx + 1]
      end

      # Renders ghost text for the current buffer, if a suggestion exists.
      #
      # @private
      # @return [void]
      def render_ghost_suggestion
        buffer = whole_buffer
        @ghost_line_count = 0
        return if buffer.empty?

        suggestion = find_suggestion(buffer)
        return unless suggestion

        ghost = suggestion[buffer.size..]
        return if ghost.nil? || ghost.empty?

        render_ghost(ghost, suggestion)
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

      # Writes the ghost text (inline + extra lines) to terminal output.
      # Saves and restores cursor column so Reline's cursor tracking
      # (used for left/right arrow positioning) is not disturbed.
      #
      # If +suggestion+ is provided and colorization is enabled, the ghost
      # is rendered with syntax highlighting via IRB::Color.
      #
      # @private
      # @param [String] ghost The ghost text (suffix of the suggestion).
      # @param [String, nil] suggestion The full matching history entry.
      # @return [void]
      def render_ghost(ghost, suggestion = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        output = Reline.core.instance_variable_get(:@output)
        display_lines = ghost_display_lines(ghost, suggestion)
        @ghost_line_count = display_lines.size - 1
        @has_inline_ghost = true

        output.write(move_to_buffer_end)
        first_line = display_lines.first
        output.write(first_line) if first_line && !first_line.empty?
        write_extra_ghost_lines(display_lines.drop(1))
        origin_column = cursor_column_at_byte_pointer
        output.write("\e[#{@ghost_line_count}A") if @ghost_line_count.positive?
        output.write("\e[0G\e[#{origin_column}C")
        output.flush
      end

      # Returns ghost lines ready for terminal output (with ANSI codes).
      #
      # When colorization is enabled, the full suggestion is colorized via
      # IRB::Color and the ghost portion is extracted from the colored output.
      # Otherwise, each line is wrapped in GRAY/RESET.
      #
      # @private
      # @param [String] ghost The ghost text (suffix of the suggestion).
      # @param [String, nil] suggestion The full matching history entry.
      # @raise [StandardError]
      # @return [Array<String>]
      def ghost_display_lines(ghost, suggestion)
        if suggestion && use_colorize?
          colorize_ghost_lines(ghost, suggestion)
        else
          ghost.split("\n").map { |line| "#{GRAY}#{line}#{RESET}" }
        end
      rescue StandardError
        ghost.split("\n").map { |line| "#{GRAY}#{line}#{RESET}" }
      end

      # Checks whether syntax coloring is available and enabled.
      #
      # @private
      # @return [Boolean]
      def use_colorize?
        defined?(IRB::Color) &&
          IRB::Color.colorable? &&
          IRB.conf.fetch(:USE_COLORIZE, true)
      end

      # Colorizes the full suggestion and extracts the ghost portion.
      #
      # @private
      # @param [String] ghost The ghost text (suffix of the suggestion).
      # @param [String] suggestion The full matching history entry.
      # @return [Array<String>] Colorized ghost lines with ANSI codes.
      def colorize_ghost_lines(ghost, suggestion)
        colored = IRB::Color.colorize_code(suggestion)
        ghost_byte_start = suggestion.bytesize - ghost.bytesize
        colored_ghost = extract_ansi_colored_suffix(colored, ghost_byte_start)
        colored_ghost.split("\n").map { |line| dim_line(line) }
      end

      # Prepends each ANSI foreground color code with +2;+ (dim)
      # and strips non-color attributes (bold, underline, reverse…).
      # Inner full resets are replaced with +RESET_COLOR+ so dim
      # stays active across token boundaries.
      #
      # @private
      # @param [String] line ANSI-colored line.
      # @return [String] Dimmed ANSI-colored line.
      def dim_line(line)
        inner = line.gsub(/\e\[(\d+(?:;\d+)*)m/) do
          params = Regexp.last_match(1)
          next RESET_COLOR if params == '0'

          color = params.split(';').map(&:to_i).select { |p| FG_COLORS.include?(p) }
          color.empty? ? '' : "\e[2;#{color.join(';')}m"
        end
        "#{DIM}#{inner}#{RESET}"
      end

      # Extracts the suffix of an ANSI-colored string starting at a given
      # visible byte offset, preserving all ANSI codes.
      #
      # @private
      # @param [String] colored_text Text with embedded ANSI escape sequences.
      # @param [Integer] visible_byte_offset Offset in visible (non-ANSI) bytes.
      # @return [String]
      def extract_ansi_colored_suffix(colored_text, visible_byte_offset) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
        pos = 0
        visible = 0
        pending_code = nil

        while visible < visible_byte_offset && pos < colored_text.length
          if colored_text[pos] == "\e"
            code_start = pos
            pos = colored_text.index('m', pos)&.succ || colored_text.length
            code = colored_text[code_start...pos]

            pending_code = [RESET, "\e[m"].include?(code) ? nil : code
          else
            visible += 1
            pos += 1
          end
        end

        suffix = colored_text[pos..] || String.new
        pending_code ? "#{pending_code}#{suffix}" : suffix
      end

      # Writes extra ghost lines below the current buffer line with prompt-width alignment.
      #
      # @private
      # @param [Array<String>] lines Extra lines with ANSI codes (excluding first inline line).
      # @return [void]
      def write_extra_ghost_lines(lines)
        return if lines.empty?

        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        output = Reline.core.instance_variable_get(:@output)

        lines.each do |line|
          output.write("\n\e[K")
          output.write("\e[#{prompt_width}C") if prompt_width.positive?
          output.write(line)
        end
      end

      # Returns the terminal column where the cursor should sit (after the
      # prompt and currently typed text at +@byte_pointer+).
      #
      # @private
      # @return [Integer]
      def cursor_column_at_byte_pointer
        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        current_line = @buffer_of_lines[@line_index] || ''
        prompt_width + Reline::Unicode.calculate_width(current_line[0...@byte_pointer])
      end

      # Moves cursor to the end of the buffer line (for writing inline ghost).
      #
      # @private
      # @return [String]
      def move_to_buffer_end
        prompt_width = @prompt ? Reline::Unicode.calculate_width(@prompt) : 0
        current_line = @buffer_of_lines[@line_index] || ''
        buf_end = prompt_width + Reline::Unicode.calculate_width(current_line)
        "\e[0G\e[#{buf_end}C"
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength, SortedMethodsByCall/Waterfall
