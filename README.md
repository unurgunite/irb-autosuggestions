# Irb::Autosuggestions

Fish-like autosuggestions for IRB. As you type, gray ghost text appears showing the most likely completion
from command history. Press right arrow to accept.

## Installation

Add to your Gemfile:

```ruby
gem 'irb-autosuggestions'
```

Or install globally:

```sh
gem install irb-autosuggestions
```

Then add to `~/.irbrc`:

```ruby
require 'irb-autosuggestions'
```

## Usage

Start typing in IRB. Gray ghost text will appear after the cursor:

```
irb(main):001* [1,2,3].map do |el|
irb(main):002*   el.su☐cc      <- "cc" is gray
irb(main):003> en☐d            <- "d" is gray
```

The ghost shows the most recent matching history entry. Press **right arrow** (`->`) to accept the full multiline suggestion.

### How it works

- Suggestions come from `Reline::HISTORY` — the most recent matching entry whose prefix matches the current buffer.
- Matching is exact: the history entry must start with the current buffer (`whole_buffer`).
- Ghost text is rendered in ANSI gray (`\e[90m`) and does not modify the buffer until accepted.
- Multiline suggestions are supported — extra lines appear below the current line, aligned to the prompt width.
- The inline ghost is written on the same line as the cursor. Extra lines are cleared with `\e[J` on each render to prevent artifacts.

## Development

```sh
git clone https://github.com/unurgunite/irb-autosuggestions
cd irb-autosuggestions
bin/setup
```

### Run tests

```sh
bundle exec rake          # spec + rubocop
bundle exec rspec         # tests only
bundle exec rubocop       # lint only
```

### Generate docs

```sh
bundle exec docscribe lib/
```

### RBS signatures

```sh
bundle exec rbs parse sig/**/*.rbs
```

### Try it locally

```sh
bin/console
```

## Architecture

```
lib/
  irb/
    autosuggestions.rb                # Entry point; prepends LineEditorPatch to Reline::LineEditor
    autosuggestions/
      version.rb                      # VERSION constant
      line_editor_patch.rb            # Core patch: render ghost, right-arrow accept, history matching
  irb-autosuggestions.rb              # Proxy file for `require 'irb-autosuggestions'`

sig/
  lib/
    irb/autosuggestions/              # RBS type signatures

spec/
  irb/autosuggestions/
    line_editor_patch_spec.rb         # 17 examples
```

The gem works by prepending `Irb::Autosuggestions::LineEditorPatch` to `Reline::LineEditor`, overriding two key methods:

- `render` — clears stale ghost text with `\e[J`, then injects new ghost text into terminal output.
- `input_key` — intercepts right arrow (`ed_next_char`) to accept the current suggestion.

## Contributing

Bug reports and pull requests are welcome
at [github.com/unurgunite/irb-autosuggestions](https://github.com/unurgunite/irb-autosuggestions).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
