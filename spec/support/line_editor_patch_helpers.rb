# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
module LineEditorPatchHelpers
  # Stubs move_history to simulate Reline history navigation.
  def stub_move_history(editor)
    editor.define_singleton_method(:move_history) do |pointer, line:, cursor:| # rubocop:disable Lint/UnusedBlockArgument
      old_pointer = @history_pointer || Reline::HISTORY.size
      if old_pointer == Reline::HISTORY.size
        @line_backup_in_history = whole_buffer
      else
        Reline::HISTORY[old_pointer] = whole_buffer
      end
      if pointer == Reline::HISTORY.size
        buf = @line_backup_in_history || ''
        @history_pointer = @line_backup_in_history = nil
      else
        @history_pointer = pointer
        buf = Reline::HISTORY[pointer] || ''
      end
      @buffer_of_lines = buf.split("\n")
      @buffer_of_lines = [String.new] if @buffer_of_lines.empty?
      @line_index = line == :start ? 0 : @buffer_of_lines.size - 1
      @byte_pointer = @buffer_of_lines.last.bytesize
    end
  end

  # Temporarily sets IRB.conf[CONFIG_KEY] to +value+ for the block.
  def with_config(value)
    original = IRB.conf[Irb::Autosuggestions::LineEditorPatch::CONFIG_KEY]
    IRB.conf[Irb::Autosuggestions::LineEditorPatch::CONFIG_KEY] = value
    yield
  ensure
    IRB.conf[Irb::Autosuggestions::LineEditorPatch::CONFIG_KEY] = original
  end

  # Stubs the terminal width for geometry-related specs.
  # Stubs IOGate because the module is prepended and its own
  # +terminal_width+ would shadow an instance-level method stub.
  def stub_terminal_width(_editor, width = 80)
    allow(Reline::IOGate).to receive(:get_screen_size).and_return([24, width])
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
