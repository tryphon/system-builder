class SystemBuilder::Box

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def release_number
    @release_number ||= Time.now.strftime('%Y%m%d-%H%M')
  end
  
  def release_name
    @release_name ||= "streambox-#{release_number}"
  end

  def root_file
    "build/root"
  end

  def boot
    @boot ||= SystemBuilder::DebianBoot.new(root_file).tap do |boot|
      boot.configurators << puppet_configurator
    end

    yield @boot if block_given?
    @boot
  end

  def puppet_configurator
    @puppet_configurator ||= SystemBuilder::PuppetConfigurator.new :release_name => release_name
    yield @puppet_configurator if block_given?
    @puppet_configurator
  end

  def disk_file
    "dist/disk"
  end

  def disk_image
    @disk_image ||= SystemBuilder::DiskSquashfsImage.new(disk_file).tap do |image|
      image.boot = boot
      image.size = 200.megabytes
    end
    yield @disk_image if block_given?
    @disk_image
  end

  def iso_file
    "dist/iso"
  end

  def iso_image
    @iso_image ||= SystemBuilder::IsoSquashfsImage.new(iso_file).tap do |image|
      image.boot = boot
    end
    yield @iso_image if block_given?
    @iso_image
  end

  def nfs_file
    "dist/nfs"
  end

  def nfs_image
    @nfs_image ||= SystemBuilder::DiskNfsRootImage.new(nfs_file).tap do |image|
      image.boot = boot
    end
    yield @nfs_image if block_given?
    @nfs_image
  end

  def upgrade_directory
    "build/upgrade"
  end

  def upgrade_file
    "dist/upgrade.tar"
  end

  def upgrade_checksum
    `sha256sum #{upgrade_file}`.split.first
  end

  def create_latest_file(latest_file)
    File.open(latest_file, "w") do |f|
      f.puts "name: #{release_name}"
      f.puts "url: http://download.tryphon.eu/streambox/streambox-#{release_number}.tar"
      f.puts "checksum: #{upgrade_checksum}"
      f.puts "status_updated_at: #{Time.now}"
      f.puts "description_url: http://www.tryphon.eu/release/#{release_name}"
    end
  end

end
