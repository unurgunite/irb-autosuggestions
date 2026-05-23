# frozen_string_literal: true

require 'reline'

require_relative 'autosuggestions/version'
require_relative 'autosuggestions/line_editor_patch'

Reline::LineEditor.prepend(Irb::Autosuggestions::LineEditorPatch)
