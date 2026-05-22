# frozen_string_literal: true

require_relative 'lib/irb/autosuggestions/version'

Gem::Specification.new do |spec|
  spec.name = 'irb-autosuggestions'
  spec.version = Irb::Autosuggestions::VERSION
  spec.authors = ['unurgunite']

  spec.summary = 'Fish-like autosuggestions for irb.'
  spec.description = 'Fish-like autosuggestions for irb.'
  spec.homepage = 'https://github.com/unurgunite/irb-autosuggestions'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/unurgunite/irb-autosuggestions'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'docscribe'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rbs'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'rubocop-sorted_methods_by_call'
  spec.add_development_dependency 'yard', '>= 0.9.38'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
