# Irb::Autosuggestions

Fish-like autosuggestions for IRB. As you type, ghost text appears after the cursor showing the most likely completion
from command history. Press right arrow to accept.

![Demo](https://raw.githubusercontent.com/unurgunite/irb-autosuggestions/main/demo.gif)

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

Start typing in IRB. A faint ghost suggestion will appear after the cursor:

```
def hello[TAB]
  puts "Hello, world!"
end
```

Press **right arrow** (`->`) to accept the full suggestion into the buffer.

### Configuration

Autosuggestions are enabled by default. You can disable them in `~/.irbrc`:

```ruby
IRB.conf[:USE_AUTOSUGGESTIONS] = false
require 'irb-autosuggestions'
```

Or via environment variable:

```sh
export IRB_USE_AUTOSUGGESTIONS=false
```

### How it works

- Suggestions come from `Reline::HISTORY` — the most recent matching entry is shown.
- Matching is line-by-line: each buffer line must be a prefix of the corresponding suggestion line.
- The last buffer line is lenient: if it's blank (whitespace only), it matches any suggestion line (auto-indentation
  support).
- Ghost text is rendered with the ANSI faint attribute (`\e[2m`) and does not modify the buffer until accepted.
- Multiline suggestions are supported — extra lines appear below the current line, aligned to the prompt width.

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
      line_editor_patch.rb            # Core patch: render ghost, right-arrow accept, matching

sig/
  lib/
    irb/autosuggestions/              # RBS type signatures

spec/
  irb/autosuggestions/
    line_editor_patch_spec.rb         # 34 examples
```

The gem works by prepending `Irb::Autosuggestions::LineEditorPatch` to `Reline::LineEditor`, overriding two key methods:

- **`render`** — injects ghost text into the terminal output after Reline finishes rendering.
- **`input_key`** — intercepts right arrow (`ed_next_char`) to accept the current suggestion.

## Contributing

Bug reports and pull requests are welcome
at [github.com/unurgunite/irb-autosuggestions](https://github.com/unurgunite/irb-autosuggestions).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
