# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require "io/version"

Gem::Specification.new do |s|
  s.name        = 'ruby-io'
  s.version     = IO::VERSION
  s.authors     = ['Chuck Remes']
  s.email       = ['git@chuckremes.com']
  s.homepage    = 'http://github.com/chuckremes/ruby-io'
  s.summary     = %q{Alternative implementation of Ruby IO class.}
  s.description = %q{A green field re-implementation and redesign of the Ruby IO classes.}

  s.license = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'rspec', ['~> 3.6']
  s.add_development_dependency 'rake'
end
