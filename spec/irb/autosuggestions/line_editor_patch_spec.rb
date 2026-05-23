# frozen_string_literal: true

RSpec.describe Irb::Autosuggestions::LineEditorPatch do
  subject(:editor) do
    mod = described_class
    Object.new.tap do |obj|
      obj.define_singleton_method(:whole_buffer) do
        instance_variable_get(:@buffer_of_lines).join("\n")
      end
      obj.extend(mod)
      obj.instance_variable_set(:@buffer_of_lines, [''])
      obj.instance_variable_set(:@line_index, 0)
      obj.instance_variable_set(:@byte_pointer, 0)
    end
  end

  describe '#match_suggestion?' do
    it 'matches when buffer is a prefix of suggestion' do
      result = editor.send(:match_suggestion?, 'def f', "def foo\n  :foo\nend")
      expect(result).to be(true)
    end

    it 'matches with stripped prefix when indentation differs' do
      result = editor.send(:match_suggestion?, 'foo', '  foo')
      expect(result).to be(true)
    end

    it 'rejects when buffer is longer than suggestion' do
      result = editor.send(:match_suggestion?, "a\nb\nc", "a\nb")
      expect(result).to be(false)
    end

    it 'matches any suggestion line for trailing blank line' do
      result = editor.send(:match_suggestion?, "def foo\n  ",
                           "def foo\n  :foo\nend")
      expect(result).to be(true)
    end

    it 'matches multiline buffer against multiline suggestion' do
      result = editor.send(:match_suggestion?, "def foo\n  :f",
                           "def foo\n  :foo\nend")
      expect(result).to be(true)
    end

    it 'rejects when a non-last line differs' do
      result = editor.send(:match_suggestion?, 'def bar',
                           "def foo\n  :foo\nend")
      expect(result).to be(false)
    end

    it 'rejects on nil suggestion line' do
      result = editor.send(:match_suggestion?, "a\nb", 'a')
      expect(result).to be(false)
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
  end

  describe '#input_key with right arrow accept' do
    let(:key) { double(method_symbol: :ed_next_char) }

    before do
      editor.define_singleton_method(:rerender) { nil }
      editor.define_singleton_method(:set_current_line) do |line|
        buf = instance_variable_get(:@buffer_of_lines).dup
        buf[instance_variable_get(:@line_index)] = line
        instance_variable_set(:@buffer_of_lines, buf)
      end
      editor.instance_variable_set(:@autosuggest_suggestion,
                                   "def foo\n  :foo\nend")
      editor.instance_variable_set(:@buffer_of_lines, ['def '])
    end

    it 'sets buffer to the full suggestion when no newline in remaining' do
      editor.send(:input_key, key)
      expect(editor.instance_variable_get(:@buffer_of_lines))
        .to eq(['def foo', '  :foo', 'end'])
    end

    it 'clears the cached suggestion after accept' do
      editor.send(:input_key, key)
      expect(editor.instance_variable_get(:@autosuggest_suggestion)).to be_nil
    end

    context 'when current line is already complete' do
      before do
        editor.instance_variable_set(:@buffer_of_lines, ['def foo'])
        editor.instance_variable_set(:@autosuggest_suggestion,
                                     "def foo\n  :foo\nend")
      end

      it 'inserts remaining lines as new lines' do
        editor.send(:input_key, key)
        expect(editor.instance_variable_get(:@buffer_of_lines))
          .to eq(['def foo', '  :foo', 'end'])
      end
    end
  end

  describe 'constant values' do
    it 'uses faint ANSI code for ghost text' do
      expect(described_class::FAINT).to eq("\e[2m")
    end

    it 'uses reset ANSI code' do
      expect(described_class::RESET).to eq("\e[0m")
    end
  end
end
