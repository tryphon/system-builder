# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "system_builder/version"

Gem::Specification.new do |s|
  s.name        = "system-builder"
  s.version     = SystemBuilder::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Alban Peignier", "Florent Peyraud"]
  s.email       = ["alban@tryphon.eu", "florent@tryphon.eu"]
  s.homepage    = "http://projects.tryphon.eu/system-builder"
  s.summary     = %q{Build bootable images}
  s.description = %q{}

  s.rubyforge_project = "system-builder"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
