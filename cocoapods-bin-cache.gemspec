# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-bin-cache/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-bin-cache'
  spec.version       = CocoapodsBinCache::VERSION
  spec.authors       = ['royliu1990']
  spec.email         = ['309225529@qq.com']
  spec.description   = %q{A patch for cocoapods-binary by which you can cache prebuild binaries in a local path specified,besides,there are some function to eliminate bundle/dsyms copy bugs of cocoapods-binary.
  }
  spec.summary       = %q{Cocoapods-bianry cache patch}
  spec.homepage      = 'https://github.com/royliu1990/cocoapods-bin-cache.git'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  # spec.files = Dir['lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency "cocoapods-binary"

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
