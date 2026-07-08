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
      # Stub originals so super works for non-prefix paths.
      obj.define_singleton_method(:ed_prev_history) { |_key, arg: 1| :super_prev } # rubocop:disable Lint/UnusedBlockArgument
      obj.define_singleton_method(:ed_next_history) { |_key, arg: 1| :super_next } # rubocop:disable Lint/UnusedBlockArgument
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

  describe '#history_navigation_key?' do
    it 'returns true for :ed_prev_history' do
      key = double(method_symbol: :ed_prev_history)
      expect(editor.send(:history_navigation_key?, key)).to be true
    end

    it 'returns true for :ed_next_history' do
      key = double(method_symbol: :ed_next_history)
      expect(editor.send(:history_navigation_key?, key)).to be true
    end

    it 'returns false for non-history keys' do
      key = double(method_symbol: :ed_next_char)
      expect(editor.send(:history_navigation_key?, key)).to be false
    end

    it 'returns false when key does not respond to method_symbol' do
      expect(editor.send(:history_navigation_key?, nil)).to be false
    end
  end

  describe '#find_prev_match' do
    around do |example|
      original = Reline::HISTORY.to_a
      Reline::HISTORY.clear
      example.run
    ensure
      Reline::HISTORY.clear
      original.each { |h| Reline::HISTORY << h }
    end

    # 4 elements: indices 0-3
    before do
      ['def baz extra', 'def baz', 'c', 'def foo'].each { |h| Reline::HISTORY << h }
    end

    it 'finds the previous match backward from given pointer' do
      expect(editor.send(:find_prev_match, 'def', 3)).to eq(1)
    end

    it 'finds the previous match from base buffer' do
      expect(editor.send(:find_prev_match, 'def', nil)).to eq(3)
    end

    it 'returns nil when no match exists before pointer' do
      expect(editor.send(:find_prev_match, 'x', 0)).to be_nil
    end

    it 'returns exact match first, then longer match' do # rubocop:disable RSpec/MultipleExpectations
      # index 1 is "def baz" (exact), index 0 is "def baz extra" (longer)
      expect(editor.send(:find_prev_match, 'def baz', 3)).to eq(1)
      expect(editor.send(:find_prev_match, 'def baz', 1)).to eq(0)
    end

    it 'returns nil when start index is negative' do
      expect(editor.send(:find_prev_match, 'a', 0)).to be_nil
    end

    it 'skips consecutive duplicate entries' do # rubocop:disable RSpec/ExampleLength
      Reline::HISTORY.clear
      %w[exit exit 123 exit exit].each { |h| Reline::HISTORY << h }
      aggregate_failures do
        expect(editor.send(:find_prev_match, 'ex', nil)).to eq(4)
        expect(editor.send(:find_prev_match, 'ex', 4)).to eq(1)
      end
    end

    it 'does NOT dedup when buffer is empty (no prefix)' do # rubocop:disable RSpec/MultipleExpectations
      Reline::HISTORY.clear
      %w[exit exit exit exit ex123+123 exit exit].each { |h| Reline::HISTORY << h }
      expect(editor.send(:find_prev_match, '', nil)).to eq(6)
      expect(editor.send(:find_prev_match, '', 6)).to eq(5)
      expect(editor.send(:find_prev_match, '', 5)).to eq(4)
    end
  end

  describe '#find_next_match' do
    around do |example|
      original = Reline::HISTORY.to_a
      Reline::HISTORY.clear
      example.run
    ensure
      Reline::HISTORY.clear
      original.each { |h| Reline::HISTORY << h }
    end

    # 4 elements: indices 0-3
    before do
      ['def baz', 'a', 'def foo', 'c'].each { |h| Reline::HISTORY << h }
    end

    it 'finds the next match forward from given pointer' do
      expect(editor.send(:find_next_match, 'def', 0)).to eq(2)
    end

    it 'returns exact match first, then longer match' do # rubocop:disable RSpec/MultipleExpectations
      Reline::HISTORY.clear
      ['def baz', 'def baz', 'def baz extra'].each { |h| Reline::HISTORY << h }
      # Index 1 is exact match, index 2 is longer match
      expect(editor.send(:find_next_match, 'def baz', 0)).to eq(1)
      expect(editor.send(:find_next_match, 'def baz', 1)).to eq(2)
    end

    it 'returns nil when pointer is nil' do
      expect(editor.send(:find_next_match, 'def', nil)).to be_nil
    end

    it 'returns nil when no match exists after pointer' do
      expect(editor.send(:find_next_match, 'def', 2)).to be_nil
    end

    it 'returns nil when start index exceeds history' do
      expect(editor.send(:find_next_match, 'def', 5)).to be_nil
    end

    it 'skips consecutive duplicate entries when going forward' do # rubocop:disable RSpec/ExampleLength
      Reline::HISTORY.clear
      %w[exit exit 123 exit exit].each { |h| Reline::HISTORY << h }
      aggregate_failures do
        expect(editor.send(:find_next_match, 'ex', 0)).to eq(1)
        expect(editor.send(:find_next_match, 'ex', 1)).to eq(4)
      end
    end

    it 'lands on the last entry of each duplicate run like find_prev_match' do
      Reline::HISTORY.clear
      %w[exit exit 123 exit exit].each { |h| Reline::HISTORY << h }
      prev = editor.send(:find_prev_match, 'ex', nil)
      nxt = editor.send(:find_next_match, 'ex', prev)
      expect(nxt).to be_nil
    end

    it 'does NOT dedup when buffer is empty (no prefix)' do # rubocop:disable RSpec/MultipleExpectations
      Reline::HISTORY.clear
      %w[exit exit exit exit ex123+123 exit exit].each { |h| Reline::HISTORY << h }
      expect(editor.send(:find_next_match, '', 0)).to eq(1)
      expect(editor.send(:find_next_match, '', 1)).to eq(2)
      expect(editor.send(:find_next_match, '', 2)).to eq(3)
    end
  end

  describe '#ed_prev_history (prefix navigation)' do
    around do |example|
      original = Reline::HISTORY.to_a
      Reline::HISTORY.clear
      example.run
    ensure
      Reline::HISTORY.clear
      original.each { |h| Reline::HISTORY << h }
    end

    before do
      stub_move_history(editor)
      # 4 elements: indices 0-3
      ['a', 'def baz', 'c', 'def foo'].each { |h| Reline::HISTORY << h }
    end

    it 'navigates to the most recent matching entry from base buffer' do # rubocop:disable RSpec/ExampleLength
      editor.instance_variable_set(:@buffer_of_lines, ['def '])
      editor.send(:ed_prev_history, nil)
      aggregate_failures do
        expect(editor.instance_variable_get(:@buffer_of_lines)).to eq(['def foo'])
        expect(editor.instance_variable_get(:@history_pointer)).to eq(3)
      end
    end

    it 'fixes the prefix anchor on first movement' do
      editor.instance_variable_set(:@buffer_of_lines, ['def '])
      editor.send(:ed_prev_history, nil)
      expect(editor.instance_variable_get(:@prefix_buffer)).to eq('def ')
    end

    it 'stops when no more matches exist' do
      editor.instance_variable_set(:@buffer_of_lines, ['def '])
      3.times { editor.send(:ed_prev_history, nil) }
      expect(editor.instance_variable_get(:@history_pointer)).to eq(1)
    end

    it 'skips consecutive duplicates during full history walk' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
      Reline::HISTORY.clear
      %w[exit exit exit 123+123 exit exit].each { |h| Reline::HISTORY << h }
      editor.instance_variable_set(:@buffer_of_lines, ['ex'])
      editor.send(:ed_prev_history, nil)
      expect(editor.instance_variable_get(:@history_pointer)).to eq(5)
      editor.send(:ed_prev_history, nil)
      expect(editor.instance_variable_get(:@history_pointer)).to eq(2)
      editor.send(:ed_prev_history, nil)
      expect(editor.instance_variable_get(:@history_pointer)).to eq(2)
    end

    it 'does nothing when buffer is empty (falls through to super)' do
      expect(editor.send(:ed_prev_history, nil)).to eq(:super_prev)
    end

    it 'does nothing when feature is disabled' do
      with_config(false) do
        editor.instance_variable_set(:@buffer_of_lines, ['def '])
        expect(editor.send(:ed_prev_history, nil)).to eq(:super_prev)
      end
    end

    it 'does nothing when moving within multiline buffer' do
      editor.instance_variable_set(:@buffer_of_lines, ['line 1', 'line 2'])
      editor.instance_variable_set(:@line_index, 1)
      expect(editor.send(:ed_prev_history, nil)).to eq(:super_prev)
    end

    it 'navigates history from a non-first line when browsing history' do # rubocop:disable RSpec/ExampleLength
      editor.instance_variable_set(:@prefix_buffer, 'def ')
      editor.instance_variable_set(:@buffer_of_lines, ['line 1', 'line 2', 'def '])
      editor.instance_variable_set(:@line_index, 1)
      editor.instance_variable_set(:@history_pointer, 3)
      editor.send(:ed_prev_history, nil)
      expect(editor.instance_variable_get(:@history_pointer)).to eq(1)
    end

    context 'with arg > 1' do
      it 'moves back multiple matches at once' do
        editor.instance_variable_set(:@buffer_of_lines, ['def '])
        editor.send(:ed_prev_history, nil, arg: 2)
        expect(editor.instance_variable_get(:@history_pointer)).to eq(1)
      end
    end
  end

  describe '#ed_next_history (prefix navigation)' do
    around do |example|
      original = Reline::HISTORY.to_a
      Reline::HISTORY.clear
      example.run
    ensure
      Reline::HISTORY.clear
      original.each { |h| Reline::HISTORY << h }
    end

    before do
      stub_move_history(editor)
      # 5 elements: indices 0-4
      ['def baz', 'a', 'def foo', 'c', 'def moo'].each { |h| Reline::HISTORY << h }
    end

    it 'navigates to the next newer matching entry' do # rubocop:disable RSpec/ExampleLength
      aggregate_failures do
        editor.instance_variable_set(:@prefix_buffer, 'def ')
        editor.instance_variable_set(:@buffer_of_lines, ['def '])
        editor.instance_variable_set(:@history_pointer, 0)
        editor.send(:ed_next_history, nil)
        expect(editor.instance_variable_get(:@buffer_of_lines)).to eq(['def foo'])
        expect(editor.instance_variable_get(:@history_pointer)).to eq(2)
      end
    end

    it 'restores the original buffer when no more forward matches' do # rubocop:disable RSpec/ExampleLength
      aggregate_failures do
        editor.instance_variable_set(:@prefix_buffer, 'def ')
        editor.instance_variable_set(:@buffer_of_lines, ['def '])
        editor.instance_variable_set(:@history_pointer, 4)
        editor.instance_variable_set(:@line_backup_in_history, 'def ')
        editor.send(:ed_next_history, nil)
        expect(editor.instance_variable_get(:@buffer_of_lines)).to eq(['def '])
        expect(editor.instance_variable_get(:@history_pointer)).to be_nil
      end
    end

    it 'does nothing when @history_pointer is nil (base buffer)' do
      expect(editor.send(:ed_next_history, nil)).to eq(:super_next)
    end

    it 'navigates forward from a non-last line when browsing history' do # rubocop:disable RSpec/ExampleLength
      editor.instance_variable_set(:@prefix_buffer, 'def ')
      editor.instance_variable_set(:@buffer_of_lines, ['def ', 'line 2', 'line 3'])
      editor.instance_variable_set(:@line_index, 1)
      editor.instance_variable_set(:@history_pointer, 0)
      editor.send(:ed_next_history, nil)
      expect(editor.instance_variable_get(:@history_pointer)).to eq(2)
    end

    it 'uses the prefix anchor when available' do
      editor.instance_variable_set(:@prefix_buffer, 'def ')
      editor.instance_variable_set(:@buffer_of_lines, ['def baz'])
      editor.instance_variable_set(:@history_pointer, 0)
      editor.send(:ed_next_history, nil)
      expect(editor.instance_variable_get(:@history_pointer)).to eq(2)
    end

    context 'with arg > 1' do
      it 'moves forward multiple matches at once' do
        editor.instance_variable_set(:@prefix_buffer, 'def ')
        editor.instance_variable_set(:@buffer_of_lines, ['def baz'])
        editor.instance_variable_set(:@history_pointer, 0)
        editor.send(:ed_next_history, nil, arg: 2)
        expect(editor.instance_variable_get(:@history_pointer)).to eq(4)
      end
    end
  end

  describe '#input_key with accept_key' do
    let(:right_key) { double(method_symbol: :ed_next_char) }
    let(:tab_key) { double(method_symbol: :ed_insert, char: "\t") }
    let(:ctrl_e_key) { double(method_symbol: :ed_end_of_line) }

    it 'calls super for non-matching keys' do
      non_match = double(method_symbol: :ed_prev_char)
      expect(editor.send(:input_key, non_match)).to eq(:original)
    end

    it 'calls super when no history match' do
      expect(editor.send(:input_key, right_key)).to eq(:original)
    end

    it 'calls super for tab when no suggestion' do
      expect(editor.send(:input_key, tab_key)).to eq(:original)
    end

    it 'calls super for ctrl+e when no suggestion' do
      expect(editor.send(:input_key, ctrl_e_key)).to eq(:original)
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

      it 'accepts on right arrow' do
        editor.send(:input_key, right_key)
        expect(editor.instance_variable_get(:@buffer_of_lines))
          .to eq(['def foo', '  :foo', 'end'])
      end

      it 'accepts on tab' do
        editor.send(:input_key, tab_key)
        expect(editor.instance_variable_get(:@buffer_of_lines))
          .to eq(['def foo', '  :foo', 'end'])
      end

      it 'accepts on ctrl+e' do
        editor.send(:input_key, ctrl_e_key)
        expect(editor.instance_variable_get(:@buffer_of_lines))
          .to eq(['def foo', '  :foo', 'end'])
      end

      it 'sets byte_pointer to the last suggestion line size' do
        editor.send(:input_key, right_key)
        expect(editor.instance_variable_get(:@byte_pointer)).to eq(3)
      end
    end

    context 'when buffer matches suggestion exactly' do
      around do |example|
        original = Reline::HISTORY.to_a
        Reline::HISTORY.clear
        Reline::HISTORY << "def foo\n  :foo\nend"
        example.run
      ensure
        Reline::HISTORY.clear
        original.each { |h| Reline::HISTORY << h }
      end

      it 'does not accept when buffer equals suggestion' do
        editor.instance_variable_set(:@buffer_of_lines, ["def foo\n  :foo\nend"])
        editor.send(:input_key, right_key)
        expect(editor.instance_variable_get(:@buffer_of_lines))
          .to eq(["def foo\n  :foo\nend"])
      end

      it 'falls through to super when buffer equals suggestion' do
        editor.instance_variable_set(:@buffer_of_lines, ["def foo\n  :foo\nend"])
        expect(editor.send(:input_key, right_key)).to eq(:original)
      end
    end

    it 'Enter key never triggers acceptance' do
      Reline::HISTORY << 'some_command'
      editor.instance_variable_set(:@buffer_of_lines, ['some_c'])
      enter_key = double(method_symbol: :ed_newline)
      expect(editor.send(:input_key, enter_key)).to eq(:original)
    end

    context 'with custom accept keys config' do
      around do |example|
        original = IRB.conf[described_class::ACCEPT_KEYS_CONFIG]
        IRB.conf[described_class::ACCEPT_KEYS_CONFIG] = %i[ed_prev_char]
        example.run
      ensure
        if original.nil?
          IRB.conf.delete(described_class::ACCEPT_KEYS_CONFIG)
        else
          IRB.conf[described_class::ACCEPT_KEYS_CONFIG] = original
        end
      end

      it 'accepts on configured key' do
        Reline::HISTORY << 'hello'
        editor.instance_variable_set(:@buffer_of_lines, ['hel'])

        custom_key = double(method_symbol: :ed_prev_char)
        editor.send(:input_key, custom_key)
        expect(editor.instance_variable_get(:@buffer_of_lines)).to eq(['hello'])
      end

      it 'ignores keys not in config' do
        Reline::HISTORY << 'hello'
        editor.instance_variable_set(:@buffer_of_lines, ['hel'])

        editor.send(:input_key, right_key)
        expect(editor.instance_variable_get(:@buffer_of_lines)).to eq(['hel'])
      end
    end
  end

  describe '#accept_key?' do
    let(:right_key) { double(method_symbol: :ed_next_char) }

    it 'matches right arrow by default' do
      expect(editor.send(:accept_key?, right_key)).to be true
    end

    it 'does not match non-accept key' do
      key = double(method_symbol: :ed_prev_char)
      expect(editor.send(:accept_key?, key)).to be false
    end

    it 'returns false for nil' do
      expect(editor.send(:accept_key?, nil)).to be false
    end

    context 'with custom config' do
      around do |example|
        original = IRB.conf[described_class::ACCEPT_KEYS_CONFIG]
        IRB.conf[described_class::ACCEPT_KEYS_CONFIG] = %i[ed_end_of_line]
        example.run
      ensure
        if original.nil?
          IRB.conf.delete(described_class::ACCEPT_KEYS_CONFIG)
        else
          IRB.conf[described_class::ACCEPT_KEYS_CONFIG] = original
        end
      end

      it 'respects configured keys' do
        key = double(method_symbol: :ed_end_of_line)
        expect(editor.send(:accept_key?, key)).to be true
      end
    end
  end

  describe '#key_match?' do
    it 'matches :ed_next_char against right arrow key' do
      key = double(method_symbol: :ed_next_char)
      expect(editor.send(:key_match?, key, :ed_next_char)).to be true
    end

    it 'matches :ed_end_of_line against ctrl+e key' do
      key = double(method_symbol: :ed_end_of_line)
      expect(editor.send(:key_match?, key, :ed_end_of_line)).to be true
    end

    it 'matches :tab against tab key' do
      key = double(method_symbol: :ed_insert, char: "\t")
      expect(editor.send(:key_match?, key, :tab)).to be true
    end

    it 'rejects tab key for non-tab symbol' do
      key = double(method_symbol: :ed_insert, char: "\t")
      expect(editor.send(:key_match?, key, :ed_next_char)).to be false
    end

    it 'rejects non-tab insert for :tab symbol' do
      key = double(method_symbol: :ed_insert, char: 'a')
      expect(editor.send(:key_match?, key, :tab)).to be false
    end

    it 'returns false for nil key' do
      expect(editor.send(:key_match?, nil, :ed_next_char)).to be false
    end

    it 'returns false when key does not respond to method_symbol' do
      expect(editor.send(:key_match?, Object.new, :ed_next_char)).to be false
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

  describe '#ghost_color' do
    after do
      IRB.conf.delete(described_class::GHOST_COLOR_CONFIG)
      IRB.conf.delete(described_class::GHOST_STYLE_CONFIG)
    end

    it 'returns default gray by default' do
      expect(editor.send(:ghost_color)).to eq("\e[90m")
    end

    it 'returns configured ANSI color' do
      IRB.conf[described_class::GHOST_COLOR_CONFIG] = "\e[32m"
      expect(editor.send(:ghost_color)).to eq("\e[32m")
    end

    it 'GHOST_STYLE takes precedence over GHOST_COLOR' do
      IRB.conf[described_class::GHOST_COLOR_CONFIG] = "\e[32m"
      IRB.conf[described_class::GHOST_STYLE_CONFIG] = { fg: :red }
      expect(editor.send(:ghost_color)).to eq("\e[31m")
    end
  end

  describe '#ghost_display_lines with custom color' do
    after do
      IRB.conf.delete(described_class::GHOST_COLOR_CONFIG)
    end

    it 'uses configured color instead of default gray' do
      IRB.conf[described_class::GHOST_COLOR_CONFIG] = "\e[32m"
      lines = editor.send(:ghost_display_lines, 'foo', nil)
      expect(lines).to eq(["\e[32mfoo\e[0m"])
    end

    it 'uses custom color in fallback on error' do
      IRB.conf[described_class::GHOST_COLOR_CONFIG] = "\e[31m"
      allow(IRB::Color).to receive(:colorize_code).and_raise(StandardError)
      lines = editor.send(:ghost_display_lines, 'foo', 'anything')
      expect(lines).to eq(["\e[31mfoo\e[0m"])
    end
  end

  describe '#resolve_ghost_style' do
    it 'resolves fg color to ANSI code' do
      expect(editor.send(:resolve_ghost_style, { fg: :red })).to eq("\e[31m")
    end

    it 'resolves bright color' do
      expect(editor.send(:resolve_ghost_style, { fg: :bright_white })).to eq("\e[97m")
    end

    it 'resolves italic attribute' do
      expect(editor.send(:resolve_ghost_style, { italic: true })).to eq("\e[3m")
    end

    it 'resolves bold attribute' do
      expect(editor.send(:resolve_ghost_style, { bold: true })).to eq("\e[1m")
    end

    it 'combines fg and attributes' do
      expect(editor.send(:resolve_ghost_style, { fg: :bright_black, italic: true }))
        .to eq("\e[90;3m")
    end

    it 'handles empty hash' do
      expect(editor.send(:resolve_ghost_style, {})).to eq("\e[m")
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
