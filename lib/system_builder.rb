$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module SystemBuilder

  @@configurations = {}
  
  def self.config(name, value = nil, &block)
    value = (value or block.call)
    puts "* load configuration #{name}"
    @@configurations[name.to_s] = value
  end

  def self.configuration(name)
    @@configurations[name.to_s]
  end

end

require 'system_builder/version'
require 'system_builder/core_ext'
require 'system_builder/disk_image'
require 'system_builder/live_image'
require 'system_builder/init_ram_fs_configurator'
require 'system_builder/disk_squashfs_image'
require 'system_builder/disk_nfsroot_image'
require 'system_builder/iso_squashfs_image'
require 'system_builder/boot'
require 'system_builder/configurator'
require 'system_builder/latest_file'
require 'system_builder/box'
