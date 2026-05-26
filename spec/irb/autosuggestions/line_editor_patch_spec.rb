# frozen_string_literal: true

RSpec.describe Irb::Autosuggestions::LineEditorPatch do
  subject(:editor) do
    Object.new.tap do |obj|
      obj.define_singleton_method(:whole_buffer) do
        instance_variable_get(:@buffer_of_lines).join("\n")
      end
      obj.define_singleton_method(:current_line) do
        instance_variable_get(:@buffer_of_lines)[
          instance_variable_get(:@line_index)
        ] || ''
      end
      obj.define_singleton_method(:input_key) { |_key| :original }
      obj.define_singleton_method(:rerender) { nil }
      obj.define_singleton_method(:set_current_line) do |line|
        buf = instance_variable_get(:@buffer_of_lines).dup
        buf[instance_variable_get(:@line_index)] = line
        instance_variable_set(:@buffer_of_lines, buf)
      end
      obj.define_singleton_method(:render) { :super_result }
      obj.singleton_class.prepend(described_class)
      obj.instance_variable_set(:@buffer_of_lines, [''])
      obj.instance_variable_set(:@line_index, 0)
      obj.instance_variable_set(:@byte_pointer, 0)
    end
  end

  describe '#find_suggestion' do
    around do |example|
      original = Reline::HISTORY.to_a
      Reline::HISTORY.clear
      example.run
    ensure
      Reline::HISTORY.clear
      original.each { |h| Reline::HISTORY << h }
    end

    it 'returns the most recent matching history entry' do
      %w[1 2].each { |h| Reline::HISTORY << h }
      expect(editor.send(:find_suggestion, '')).to eq('2')
    end

    it 'excludes the current buffer' do
      Reline::HISTORY << '1'
      editor.instance_variable_set(:@buffer_of_lines, ['1'])
      expect(editor.send(:find_suggestion, '1')).to be_nil
    end

    it 'returns nil when no history matches' do
      Reline::HISTORY << 'abc'
      expect(editor.send(:find_suggestion, 'xyz')).to be_nil
    end

    it 'returns nil with empty history' do
      expect(editor.send(:find_suggestion, 'foo')).to be_nil
    end

    it 'matches multiline buffer against multiline suggestion' do
      Reline::HISTORY << "def foo\n  :foo\nend"
      result = editor.send(:find_suggestion, "def foo\n  :f")
      expect(result).to eq("def foo\n  :foo\nend")
    end
  end

  describe '#input_key with right arrow accept' do
    let(:key) { double(method_symbol: :ed_next_char) }

    it 'calls super for non-right-arrow keys' do
      non_arrow = double(method_symbol: :ed_prev_char)
      expect(editor.send(:input_key, non_arrow)).to eq(:original)
    end

    it 'calls super when no history match' do
      expect(editor.send(:input_key, key)).to eq(:original)
    end

    context 'with matching history' do
      around do |example|
        original = Reline::HISTORY.to_a
        Reline::HISTORY.clear
        Reline::HISTORY << "def foo\n  :foo\nend"
        example.run
      ensure
        Reline::HISTORY.clear
        original.each { |h| Reline::HISTORY << h }
      end

      before do
        editor.instance_variable_set(:@buffer_of_lines, ['def '])
      end

      it 'accepts the full multiline suggestion' do
        editor.send(:input_key, key)
        expect(editor.instance_variable_get(:@buffer_of_lines))
          .to eq(['def foo', '  :foo', 'end'])
      end

      it 'sets byte_pointer to the last suggestion line size' do
        editor.send(:input_key, key)
        expect(editor.instance_variable_get(:@byte_pointer)).to eq(3)
      end
    end
  end

  describe '#accept_suggestion' do
    before do
      editor.instance_variable_set(:@buffer_of_lines, ['def '])
      editor.instance_variable_set(:@line_index, 0)
    end

    it 'replaces the buffer with suggestion lines' do
      editor.send(:accept_suggestion, "def foo\n  :foo\nend")
      expect(editor.instance_variable_get(:@buffer_of_lines))
        .to eq(['def foo', '  :foo', 'end'])
    end

    it 'sets line_index to the last line' do
      editor.send(:accept_suggestion, "def foo\n  :foo\nend")
      expect(editor.instance_variable_get(:@line_index)).to eq(2)
    end

    it 'sets byte_pointer to the last line size' do
      editor.send(:accept_suggestion, "def foo\n  :foo\nend")
      expect(editor.instance_variable_get(:@byte_pointer)).to eq(3)
    end

    it 'handles single-line suggestions' do
      editor.send(:accept_suggestion, 'single line')
      expect(editor.instance_variable_get(:@buffer_of_lines))
        .to eq(['single line'])
    end
  end

  describe '#render' do
    it 'returns super result' do
      expect(editor.send(:render)).to eq(:super_result)
    end

    context 'when disabled via IRB.conf' do
      around do |example|
        original = IRB.conf[described_class::CONFIG_KEY]
        IRB.conf[described_class::CONFIG_KEY] = false
        example.run
      ensure
        IRB.conf[described_class::CONFIG_KEY] = original
      end

      it 'returns super result without ghost' do
        expect(editor.send(:render)).to eq(:super_result)
      end
    end
  end

  describe '#enabled?' do
    around do |example|
      original_env = ENV.fetch(described_class::ENV_KEY, nil)
      original_conf = IRB.conf[described_class::CONFIG_KEY]
      example.run
    ensure
      ENV[described_class::ENV_KEY] = original_env
      IRB.conf[described_class::CONFIG_KEY] = original_conf
    end

    it 'is true by default' do
      ENV.delete(described_class::ENV_KEY)
      IRB.conf.delete(described_class::CONFIG_KEY)
      expect(editor.send(:enabled?)).to be true
    end

    it 'returns false when IRB.conf key is false' do
      ENV.delete(described_class::ENV_KEY)
      IRB.conf[described_class::CONFIG_KEY] = false
      expect(editor.send(:enabled?)).to be false
    end

    it 'returns true when IRB.conf key is true' do
      ENV.delete(described_class::ENV_KEY)
      IRB.conf[described_class::CONFIG_KEY] = true
      expect(editor.send(:enabled?)).to be true
    end

    it 'returns false when env var is 0' do
      IRB.conf[described_class::CONFIG_KEY] = true
      ENV[described_class::ENV_KEY] = '0'
      expect(editor.send(:enabled?)).to be false
    end

    it 'returns true when env var is 1' do
      IRB.conf[described_class::CONFIG_KEY] = true
      ENV[described_class::ENV_KEY] = '1'
      expect(editor.send(:enabled?)).to be true
    end

    it 'env var overrides IRB.conf' do
      IRB.conf[described_class::CONFIG_KEY] = false
      ENV[described_class::ENV_KEY] = '1'
      expect(editor.send(:enabled?)).to be true
    end
  end

  describe '#extract_ansi_colored_suffix' do
    it 'extracts suffix preserving leading ANSI codes' do
      colored = "plain\e[32mcolored\e[0m"
      expect(editor.send(:extract_ansi_colored_suffix, colored, 5))
        .to eq("\e[32mcolored\e[0m")
    end

    it 'extracts from between ANSI tokens' do
      colored = "\e[32mdef\e[0m \e[36mfoo\e[0m"
      expect(editor.send(:extract_ansi_colored_suffix, colored, 4))
        .to eq("\e[36mfoo\e[0m")
    end

    it 'returns full string when offset is zero' do
      colored = "\e[32mtext\e[0m"
      expect(editor.send(:extract_ansi_colored_suffix, colored, 0))
        .to eq(colored)
    end

    it 'returns empty string when offset exceeds visible length' do
      colored = "\e[32mabc\e[0m"
      expect(editor.send(:extract_ansi_colored_suffix, colored, 99))
        .to eq('')
    end

    it 'handles uncolored text' do
      expect(editor.send(:extract_ansi_colored_suffix, 'hello', 2))
        .to eq('llo')
    end
  end

  describe '#ghost_display_lines' do
    it 'wraps ghost in gray when suggestion is nil' do
      lines = editor.send(:ghost_display_lines, 'foo', nil)
      expect(lines).to eq(["\e[90mfoo\e[0m"])
    end

    it 'wraps multiline ghost in gray when suggestion is nil' do
      lines = editor.send(:ghost_display_lines, "foo\nbar", nil)
      expect(lines).to eq(["\e[90mfoo\e[0m", "\e[90mbar\e[0m"])
    end

    context 'when colorize is enabled' do
      around do |example|
        original = IRB.conf[:USE_COLORIZE]
        IRB.conf[:USE_COLORIZE] = true
        example.run
      ensure
        IRB.conf[:USE_COLORIZE] = original
      end

      before do
        allow(IRB::Color).to receive(:colorable?).and_return(true)
        allow(IRB::Color).to receive(:colorize_code) do |code|
          # Simulate per-token ANSI coloring (like real IRB::Color)
          code.gsub(/(\w+)/) { "\e[32m#{Regexp.last_match(1)}\e[0m" }
        end
      end

      it 'colorizes and extracts ghost portion' do
        lines = editor.send(:ghost_display_lines, 'foo', 'def foo')
        expect(lines).to eq(["\e[2m\e[2;32mfoo\e[39;49m\e[0m"])
      end

      it 'splits multiline colorized ghost' do
        lines = editor.send(:ghost_display_lines, "bar\nbaz", "def foo\nbar\nbaz")
        expect(lines).to eq(["\e[2m\e[2;32mbar\e[39;49m\e[0m", "\e[2m\e[2;32mbaz\e[39;49m\e[0m"])
      end

      it 'falls back to gray on error' do
        allow(IRB::Color).to receive(:colorize_code).and_raise(StandardError)
        lines = editor.send(:ghost_display_lines, 'foo', 'def foo')
        expect(lines).to eq(["\e[90mfoo\e[0m"])
      end
    end
  end

  describe '#use_colorize?' do
    around do |example|
      original = IRB.conf[:USE_COLORIZE]
      example.run
    ensure
      IRB.conf[:USE_COLORIZE] = original
    end

    it 'returns false when IRB::Color.colorable? is false' do
      IRB.conf[:USE_COLORIZE] = true
      expect(editor.send(:use_colorize?)).to be false
    end

    it 'returns true when IRB::Color.colorable? is true and USE_COLORIZE is set' do
      IRB.conf[:USE_COLORIZE] = true
      allow(IRB::Color).to receive(:colorable?).and_return(true)
      expect(editor.send(:use_colorize?)).to be true
    end

    it 'returns false when USE_COLORIZE is false' do
      IRB.conf[:USE_COLORIZE] = false
      allow(IRB::Color).to receive(:colorable?).and_return(true)
      expect(editor.send(:use_colorize?)).to be false
    end
  end

  describe 'constant values' do
    it 'uses gray ANSI code for ghost text' do
      expect(described_class::GRAY).to eq("\e[90m")
    end

    it 'uses reset ANSI code' do
      expect(described_class::RESET).to eq("\e[0m")
    end
  end
end
