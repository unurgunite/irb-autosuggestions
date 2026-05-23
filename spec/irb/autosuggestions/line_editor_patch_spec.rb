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
        ] || ""
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
