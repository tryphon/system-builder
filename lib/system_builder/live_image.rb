require 'tempfile'

class SystemBuilder::LiveImage

  attr_accessor :boot, :size
  attr_reader :file

  def initialize(file)
    @file = file
    @size = 512.megabytes
  end

  def create
    boot.configurators << SystemBuilder::ProcConfigurator.new do |chroot|
      puts "* install live-initramfs"
      chroot.apt_install %w{live-initramfs}
    end

    boot.create

    file_creation = (not File.exists?(file))
    if file_creation
      create_file
      create_partition_table

      format_boot_fs
    end

    install_syslinux_files

    sync_boot_fs
    compress_root_fs
    install_syslinux

    self
  end

  def create_file
    FileUtils::sh "dd if=/dev/zero of=#{file} count=#{size.in_megabytes.to_i} bs=1M"
  end

  def create_partition_table
    # Partition must be bootable for syslinux
    FileUtils::sh "echo '#{free_sectors},,b,*' | /sbin/sfdisk --no-reread -uS -H16 -S63 #{file}"
  end
 
  def format_boot_fs
    loop_device = "/dev/loop0"
    begin
      FileUtils::sudo "losetup -o #{boot_fs_offset} #{loop_device} #{file}"
      FileUtils::sudo "mkdosfs -v -F 32 #{loop_device} #{boot_fs_block_size}"
    ensure
      FileUtils::sudo "losetup -d #{loop_device}"
    end
  end

  def mount_boot_fs(&block)
    # TODO use a smarter mount_dir
    mount_dir = "/tmp/mount_boot_fs"
    FileUtils::mkdir_p mount_dir

    begin
      FileUtils::sudo "mount -o loop,offset=#{boot_fs_offset} #{file} #{mount_dir}"
      yield mount_dir
    ensure
      FileUtils::sudo "umount #{mount_dir}"
    end
  end

  def compress_root_fs
    mount_boot_fs do |mount_dir|
      FileUtils::sudo "mksquashfs #{boot.root}/ #{mount_dir}/live/filesystem.squashfs -e #{boot.root}/boot"
    end
    FileUtils.touch file
  end
  
  def sync_boot_fs
    mount_boot_fs do |mount_dir|
      FileUtils::sudo "rsync -a --delete #{boot.root}/boot/ #{mount_dir}/live"
    end
    FileUtils.touch file
  end

  def install_syslinux_files(options = {})
    version = (options[:version] or Time.now.strftime("%Y%m%d%H%M"))

    mount_boot_fs do |mount_dir|
      SystemBuilder::DebianBoot::Image.new(mount_dir).tap do |image|
        image.open("/syslinux.cfg") do |f|
          f.puts "default linux"
          f.puts "label linux"
          f.puts "kernel /live/#{readlink_boot_file('vmlinuz')}"
          f.puts "append ro boot=live initrd=/live/#{readlink_boot_file('initrd.img')} persistent=nofiles"
          # console=tty0 console=ttyS0
        end
      end
    end
    FileUtils.touch file
  end

  def readlink_boot_file(boot_file)
    File.basename(%x{readlink #{boot.root}/#{boot_file}}.strip)
  end

  def install_syslinux
    FileUtils::sh "syslinux -o #{boot_fs_offset} #{file}"
    FileUtils::sh "dd if=/usr/lib/syslinux/mbr.bin of=#{file} conv=notrunc"
  end

  def convert(export_file, options = {})
    unless FileUtils.uptodate? export_file, file
      arguments = []
      arguments << "-O #{options[:format]}" if options[:format]
      FileUtils::sh "qemu-img convert -f raw #{file} #{arguments.join(' ')} #{export_file}"
    end
  end

  def free_sectors
    64
  end

  def boot_fs_offset
    free_sectors * 512
  end

  def boot_fs_block_size
    linux_partition_info = `/sbin/sfdisk -l #{file}`.scan(%r{#{file}.*W95 FAT32}).first
    linux_partition_info.split[5].to_i
  end
end
