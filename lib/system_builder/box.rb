require 'vmbox'

class SystemBuilder::Box

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def release_number
    @release_number ||= Time.now.strftime('%Y%m%d-%H%M')
  end

  def release_name
    @release_name ||= "#{name}-#{release_number}"
  end

  attr_accessor :named_mode
  alias_method :named_mode?, :named_mode

  def build_dir
    named_mode? ? "build/#{name}" : "build"
  end

  def dist_dir
    named_mode? ? "dist/#{name}" : "dist"
  end

  def root_file
    "#{build_dir}/root"
  end

  def boot
    @boot ||= SystemBuilder::DebianBoot.new(root_file)
    unless @boot_configurated
      @boot_configurated = true

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

  def create_latest_file(latest_file = latest_file)
    SystemBuilder::LatestFile.new(:name => name, :release_number => release_number, :upgrade_file => upgrade_file).create(latest_file)
  end

  def latest_file
    "#{dist_dir}/latest.yml"
  end

  @@box_list = %w{streambox playbox pigebox linkbox playbox rivendellallbox rivendellairbox rivendellnasbox soundbox}
  def default_vmbox_index
    @@box_list.index name.to_s
  end

  def vmbox_index
    ENV['VMBOX_INDEX'].try(:to_i) || default_vmbox_index
  end

  def vmbox
    @vmbox ||= VMBox.new(name, :root_dir => Pathname.new(dist_dir), :architecture => boot.architecture, :index => vmbox_index)
  end

end
