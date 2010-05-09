# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{system-builder}
  s.version = "0.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alban Peignier"]
  s.date = %q{2010-05-09}
  s.default_executable = %q{system-builder}
  s.description = %q{FIX (describe your package)}
  s.email = ["alban@tryphon.eu"]
  s.executables = ["system-builder"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "PostInstall.txt"]
  s.files = ["History.txt", "Manifest.txt", "PostInstall.txt", "README.rdoc", "Rakefile", "bin/system-builder", "examples/Rakefile", "examples/config.rb", "examples/manifests/classes/test.pp", "examples/manifests/site.pp", "features/development.feature", "features/step_definitions/common_steps.rb", "features/support/common.rb", "features/support/env.rb", "features/support/matchers.rb", "lib/system_builder.rb", "lib/system_builder/boot.rb", "lib/system_builder/cli.rb", "lib/system_builder/configurator.rb", "lib/system_builder/core_ext.rb", "lib/system_builder/disk_image.rb", "lib/system_builder/disk_squashfs_image.rb", "lib/system_builder/init_ram_fs_configurator.rb", "lib/system_builder/iso_image.rb", "lib/system_builder/iso_squashfs_image.rb", "lib/system_builder/live_image.rb", "lib/system_builder/mount_boot.sh", "lib/system_builder/task.rb", "script/console", "script/destroy", "script/generate", "spec/spec.opts", "spec/spec_helper.rb", "spec/system_builder/boot_spec.rb", "spec/system_builder/cli_spec.rb", "system-builder.gemspec", "tasks/rspec.rake"]
  s.homepage = %q{http://projects.tryphon.eu/system-builder}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{system-builder}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{FIX (describe your package)}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, [">= 2.6.0"])
    else
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, [">= 2.6.0"])
    end
  else
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, [">= 2.6.0"])
  end
end
