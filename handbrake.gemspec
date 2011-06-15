# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "handbrake/version"

Gem::Specification.new do |s|
  s.name        = "handbrake"
  s.version     = HandBrake::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Rhett Sutphin"]
  s.email       = ["rhett@detailedbalance.net"]
  s.homepage    = "https://github.com/rsutphin/handbrake.rb"
  s.summary     = %q{A ruby wrapper for HandBrakeCLI}
  s.description = %q{A lightweight literate ruby wrapper for HandBrakeCLI, the command-line interface for the HandBrake video transcoder.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'rubytree', '~> 0.8.1'

  s.add_development_dependency 'rspec', '~> 2.5'
  s.add_development_dependency 'rake', '~> 0.9.0'
  s.add_development_dependency 'yard', '~> 0.7.0'
end
