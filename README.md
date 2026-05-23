# Irb::Autosuggestions

[![Gem Version](https://badge.fury.io/rb/irb-autosuggestions.svg)](https://rubygems.org/gems/irb-autosuggestions)
[![CI](https://github.com/unurgunite/irb-autosuggestions/actions/workflows/ci.yml/badge.svg)](https://github.com/unurgunite/irb-autosuggestions/actions)

![Irb::Autosuggestions](readme.png)

No need to explain. Fish-like autosuggestions for IRB — ghost text from history as you type.

## Contents

* [Irb::Autosuggestions](#irbautosuggestions)
    * [Contents](#contents)
    * [Installation](#installation)
    * [Usage](#usage)
        * [How it works](#how-it-works)
    * [Development](#development)
    * [License](#license)

## Installation

Add to your Gemfile:

```ruby
gem 'irb-autosuggestions'
```

`~/.irbrc`:

```ruby
require 'irb-autosuggestions'
```

## Usage

Start typing in IRB. Gray ghost text appears after the cursor, showing the most recent matching history entry:

```
irb(main):001* [1,2,3].map do |el|
irb(main):002*   el.succ      <- "cc" in gray
irb(main):003> end            <- "d" in gray
```

Press **right arrow** (`->`) to accept the full multiline suggestion.

### How it works

- Each keystroke queries `Reline::HISTORY` for the most recent entry whose prefix matches the current buffer.
- The suggestion is rendered inline as gray (`\e[90m`) text without modifying the buffer.
- Extra ghost lines (for multiline history entries) are drawn below the prompt.
- `\e[J` clears stale ghost artifacts from the viewport.
- Right arrow triggers `ed_next_char`, which replaces the buffer with the ghost text.

## Development

```sh
bin/setup
bundle exec rake          # spec + rubocop
```

## License

MIT
