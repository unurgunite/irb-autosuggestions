# frozen_string_literal: true

module Irb
  module Autosuggestions
    module LineEditorPatch
      RESET = "\e[0m"
      FAINT = "\e[2m"

      # Method documentation.
      #
      # @return [Object]
      def render(...)
        result = super

        output = Reline.core.instance_variable_get(:@output)
        full = whole_buffer

        if @autosuggest_ghost_length
          output.write("\e[K")
          @autosuggest_ghost_length = nil
        end

        if @autosuggest_extra_count&.positive?
          output.write("\e[s")
          @autosuggest_extra_count.times do
            output.write("\n\e[K")
          end
          output.write("\e[#{@autosuggest_extra_count}A")
          output.write("\e[u")
          @autosuggest_extra_count = nil
        end

        return result if full.strip.empty?

        if !@autosuggest_suggestion
          @autosuggest_suggestion = find_suggestion(full)
          return result unless @autosuggest_suggestion
        elsif !match_suggestion?(full, @autosuggest_suggestion)
          @autosuggest_suggestion = nil
          return result
        end

        return result if @autosuggest_suggestion == full

        ghost = @autosuggest_suggestion[full.size..]
        return result if ghost.nil? || ghost.empty?

        ghost_lines = ghost.lines.map(&:chomp)
        return result if ghost_lines.empty?

        current_ghost, *extra_lines = ghost_lines

        output.write("\e[s")

        unless current_ghost.empty?
          output.write("#{FAINT}#{current_ghost}#{RESET}")
          @autosuggest_ghost_length = current_ghost.length
        end

        if extra_lines.any?
          pmt = @prompt
          pw = pmt ? Reline::Unicode.calculate_width(pmt) : 0
          extra_lines.each do |gl|
            output.write("\n")
            output.write("\e[#{pw}C") if pw.positive?
            output.write("#{FAINT}#{gl}#{RESET}")
          end
          @autosuggest_extra_count = extra_lines.size
        end

        output.write("\e[u")
        output.flush

        result
      end

      # Method documentation.
      #
      # @param [Object] key Param documentation.
      # @return [Object]
      def input_key(key)
        if right_arrow?(key)
          buffer = current_buffer
          suggestion = @autosuggest_suggestion

          if suggestion && match_suggestion?(whole_buffer, suggestion) && suggestion != whole_buffer
            remaining = suggestion[whole_buffer.size..]

            if remaining && !remaining.empty?
              if remaining.start_with?("\n")
                remaining = remaining[1..].to_s
                remaining.split("\n").each do |rl|
                  @buffer_of_lines.insert(@line_index + 1, rl)
                  @line_index += 1
                  @byte_pointer = rl.bytesize
                end
              else
                remaining.split("\n").each_with_index do |rl, i|
                  if i.zero?
                    line = buffer + rl
                    set_current_line(line)
                    @byte_pointer = line.bytesize
                  else
                    @buffer_of_lines.insert(@line_index + 1, rl)
                    @line_index += 1
                    @byte_pointer = rl.bytesize
                  end
                end
              end

              @autosuggest_suggestion = nil
              rerender
              return
            end
          end
        end

        super
      end

      private

      # Method documentation.
      #
      # @private
      # @param [Object] buffer Param documentation.
      # @return [Object]
      def find_suggestion(buffer)
        Reline::HISTORY.reverse.find do |h|
          h != whole_buffer && match_suggestion?(buffer, h)
        end
      end

      # Method documentation.
      #
      # @private
      # @param [Object] key Param documentation.
      # @return [Object]
      def right_arrow?(key)
        key.respond_to?(:method_symbol) && key.method_symbol == :ed_next_char
      end

      # Method documentation.
      #
      # @private
      # @return [Object]
      def current_buffer
        @buffer_of_lines[@line_index] || ''
      end

      # Method documentation.
      #
      # @private
      # @param [Object] buffer Param documentation.
      # @param [Object] suggestion Param documentation.
      # @return [Object]
      def match_suggestion?(buffer, suggestion)
        buf_lines = buffer.split("\n", -1)
        sug_lines = suggestion.split("\n", -1)
        return false if buf_lines.size > sug_lines.size

        buf_lines.each_with_index.all? do |bl, i|
          sl = sug_lines[i]
          next false unless sl

          if i == buf_lines.size - 1 && bl.strip.empty?
            true
          else
            sl.start_with?(bl) || (!bl.strip.empty? && sl.strip.start_with?(bl.strip))
          end
        end
      end
    end
  end
end
