# Irb::Autosuggestions

[![Gem Version](https://badge.fury.io/rb/irb-autosuggestions.svg)](https://rubygems.org/gems/irb-autosuggestions)
[![RubyGems Downloads](https://img.shields.io/gem/dt/irb-autosuggestions.svg)](https://rubygems.org/gems/irb-autosuggestions)
[![CI](https://github.com/unurgunite/irb-autosuggestions/actions/workflows/ci.yml/badge.svg)](https://github.com/unurgunite/irb-autosuggestions/actions)
[![License](https://img.shields.io/github/license/unurgunite/irb-autosuggestions.svg)](https://github.com/unurgunite/irb-autosuggestions/blob/master/LICENSE.txt)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7-blue.svg)](#installation)

![Irb::Autosuggestions](readme.png)

No need to explain. Fish-like autosuggestions for IRB — ghost text from history as you type.

## Contents

* [Irb::Autosuggestions](#irbautosuggestions)
    * [Contents](#contents)
    * [Installation](#installation)
    * [Usage](#usage)
        * [Prefix-filtered history navigation](#prefix-filtered-history-navigation)
    * [Configuration](#configuration)
        * [Ghost color](#ghost-color)
        * [Colors](#colors)
        * [Accept keys](#accept-keys)
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

Start typing in IRB. Ghost text appears after the cursor, showing the most recent matching history entry with syntax
coloring (or gray if colorization is unavailable or disabled):

```
irb(main):001* [1,2,3].map do |el|
irb(main):002*   el.succ      <- "cc" in gray
irb(main):003> end            <- "d" in gray
```

Press **right arrow** (`->`), **Tab**, **Ctrl+F**, or **Ctrl+E** to accept the full multiline suggestion. Tab falls
back to normal completion when no suggestion is visible. Accept keys are configurable (see below).

### Prefix-filtered history navigation

**Up/down arrows** navigate history filtered by the typed prefix (like zsh). Start typing and press **up** — only
entries matching your prefix are shown. The prefix is frozen on the first press; subsequent presses keep searching
within that prefix:

```
irb(main):001:0> def          <- type "def", press up
irb(main):001:0> def foo      <- press up again then older "def*" entry
```

Press **right arrow** to accept the suggestion and exit prefix mode. Any non-history key (letter, enter, etc.) resets
the prefix anchor, returning arrows to normal unfiltered browsing.

Consecutive duplicate entries are collapsed during prefix search so each unique line appears once.

Regular unfiltered history browsing (empty buffer + up arrow) is unchanged — all entries are shown including duplicates.

To disable prefix navigation while keeping ghost text:

```ruby
IRB.conf[:USE_PREFIX_HISTORY_NAVIGATION] = false
```

Or via environment variable:

```sh
export IRB_PREFIX_HISTORY_NAVIGATION=0
```

## Configuration

Autosuggestions are enabled by default. To disable:

`~/.irbrc`:

```ruby
IRB.conf[:USE_AUTOSUGGESTIONS] = false
```

Or via environment variable:

```sh
export IRB_AUTOSUGGESTIONS=0
```

### Ghost color

The plain gray fallback color can be customized. Syntax-colored ghost text (when `IRB::Color` is available) always
takes precedence over these settings.

Set a raw ANSI escape code:

```ruby
IRB.conf[:AUTOSUGGESTION_GHOST_COLOR] = "\e[32m" # green
```

Or use the declarative style hash:

```ruby
IRB.conf[:AUTOSUGGESTION_GHOST_STYLE] = { fg: :bright_black, italic: true }
```

Supported colors: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, `default`,
`bright_black`, `bright_red`, `bright_green`, `bright_yellow`, `bright_blue`, `bright_magenta`,
`bright_cyan`, `bright_white`.

Supported attributes: `bold`, `dim`, `italic`, `underline`, `blink`, `reverse`.

### Colors

Syntax-colored ghost text is **enabled by default** when `IRB::Color` is available and `IRB.conf[:USE_COLORIZE]` is
true.

To disable colored ghost text (falls back to plain gray):

```ruby
IRB.conf[:USE_COLORIZE] = false
```

Or from command line:

```sh
irb --nocolorize
```

> [!NOTE]
> Colorized ghost rendering may behave differently across terminal emulators, Ruby versions, and IRB color
> schemes. If you notice visual artifacts (e.g., wrong colors, underlines, or unusual brightness), try disabling the
> feature or switch to the gray fallback or create new issue.

### Accept keys

Configure which keys accept the ghost suggestion:

```ruby
IRB.conf[:AUTOSUGGESTION_ACCEPT_KEYS] = %i[ed_next_char tab ed_end_of_line]
```

Defaults: `[:ed_next_char, :ed_end_of_line, :tab]` (right arrow/Ctrl+F, Ctrl+E, Tab).

Available symbols: `:ed_next_char` (right arrow/Ctrl+F), `:ed_end_of_line` (Ctrl+E), `:tab`, or
any Reline method symbol. When no suggestion is visible, the key falls through to its normal behavior.

### How it works

- Each keystroke queries `Reline::HISTORY` for the most recent entry whose prefix matches the current buffer.
- The suggestion is rendered inline as ghost text without modifying the buffer.
- When available, the ghost uses `IRB::Color.colorize_code` to match IRB's syntax colors, dimmed via ANSI escape codes
  for visual distinction.
- Extra ghost lines (for multiline history entries) are drawn below the prompt.
- Ghost artifacts are cleared each frame using cursor save/restore (`\e[s`/`\e[u`) and per-line clearing (`\e[2K`),
  avoiding `\e[J` which interfered with Reline's cursor tracking.
- Configurable accept keys (right arrow, Tab, Ctrl+F, Ctrl+E by default) replace the buffer with the ghost text.
- Up/down arrows use prefix-filtered navigation when the buffer is non-empty, falling back to unfiltered browsing
  when nothing was typed.

## Development

```sh
bin/setup
bundle exec rake          # spec + rubocop
```

## License

MIT
