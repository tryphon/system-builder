require 'vmbox'

class SystemBuilder::Box

  attr_reader :name

  def initialize(name)
    @name = name
  end

  attr_accessor :release_number
  def release_number
    @release_number ||= (external_release_number or self.class.default_release_number)
  end

  def external_release_number
    if env_release = ENV['BOX_RELEASE_NUMBER'] and env_release =~ /^\d{8}-\d{4}$/
      env_release
    end
  end

  def self.default_release_number
    Time.now.strftime('%Y%m%d-%H%M')
  end

  def release_name
    @release_name ||= "#{name}-#{release_number}"
  end

  attr_accessor :named_mode
  alias_method :named_mode?, :named_mode

  def working_directory(type)
    [].tap do |parts|
      parts << type.to_s
      parts << name if named_mode?
      parts << architecture if multi_architecture?
    end.join('/')
  end

  def build_dir
    @build_dir ||= working_directory :build
  end

  def dist_dir
    @dist_dir ||= working_directory :dist
  end

  def root_file
    "#{build_dir}/root"
  end

  attr_accessor :architecture
  def architecture
    @architecture ||= :amd64
  end

  attr_accessor :multi_architecture
  alias_method :multi_architecture?, :multi_architecture

  def boot
    @boot ||= SystemBuilder::DebianBoot.new(root_file)
    unless @boot_configurated
      @boot_configurated = true
      @boot.architecture = architecture

      yield @boot if block_given?
      @boot.configurators << puppet_configurator
    end
    @boot
  end

  def secret
    ENV.fetch 'BOX_SECRET', 'secret'
  end

  def puppet_configurator
    @puppet_configurator ||= SystemBuilder::PuppetConfigurator.new :box_name => name, :release_name => release_name, :debian_release => boot.version, :box_architecture => boot.architecture, :box_secret => secret
    yield @puppet_configurator if block_given?
    @puppet_configurator
  end

  def disk_file
    "#{dist_dir}/disk"
  end

  def disk_image
    @disk_image ||= SystemBuilder::DiskSquashfsImage.new(disk_file).tap do |image|
      image.boot = boot
      image.size = 4000000000
      image.build_dir = build_dir
    end
    yield @disk_image if block_given?
    @disk_image
  end

  def iso_file
    "#{dist_dir}/iso"
  end

  def iso_image
    @iso_image ||= SystemBuilder::IsoSquashfsImage.new(iso_file).tap do |image|
      image.boot = boot
      image.build_dir = build_dir
    end
    yield @iso_image if block_given?
    @iso_image
  end

  def nfs_file
    "#{dist_dir}/nfs"
  end

  def nfs_image
    @nfs_image ||= SystemBuilder::DiskNfsRootImage.new(nfs_file).tap do |image|
      image.boot = boot
    end
    yield @nfs_image if block_given?
    @nfs_image
  end

  def upgrade_directory
    "#{build_dir}/upgrade"
  end

  def upgrade_file
    "#{dist_dir}/upgrade.tar"
  end

  def release_dir
    [].tap do |parts|
      parts << name
      parts << architecture if multi_architecture?
    end.join('/')
  end

  def release_filename
    [].tap do |parts|
      parts << name
      parts << architecture if multi_architecture?
      parts << release_number
    end.join('-')
  end

  def create_latest_file(latest_file = latest_file)
    SystemBuilder::LatestFile.new(self).create(latest_file)
  end

  def latest_file
    "#{dist_dir}/latest.yml"
  end

  def vmbox
    @vmbox ||= VMBox.new(name, :root_dir => Pathname.new(dist_dir), :architecture => boot.architecture)
  end

end
