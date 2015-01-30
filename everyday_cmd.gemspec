# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'everyday_cmd/version'

Gem::Specification.new do |spec|
  spec.name          = 'everyday_cmd'
  spec.version       = EverydayCmd::VERSION
  spec.authors       = ['Eric Henderson']
  spec.email         = ['henderea@gmail.com']
  spec.summary       = %q{A CLI command system based loosely on Thor.}
  spec.description   = %q{A CLI command system based loosely on Thor. It supports multiple levels of sub-commands, flags, command and flag aliases, and helper methods.  Helpers can be in the global scope or in the command/command group scope.}
  spec.homepage      = 'https://github.com/henderea/everyday_cmd'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.4'
end
