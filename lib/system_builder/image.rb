require 'tempfile'

class SystemBuilder::DiskImage

  attr_accessor :boot, :size
  attr_reader :file

  def initialize(file)
    @file = file
    @size = 512.megabytes
  end

  def create
    boot.create
    # TODO

    file_creation = (not File.exists?(file))
    if file_creation
      create_file
      create_partition_table

      format_boot_fs
      format_root_fs
    end

    install_syslinux_files

    sync_boot_fs
    sync_root_fs

    install_syslinux

    self
  end

  def create_file
    FileUtils::sh "dd if=/dev/zero of=#{file} count=#{size.in_megabytes.to_i} bs=1M"
  end

  def create_partition_table
    # Partition must be bootable for syslinux
    FileUtils::sh "echo -e '#{free_sectors},#{boot_fs_sector_count},b,*\n#{boot_fs_sector_count+free_sectors},,L,' | /sbin/sfdisk --no-reread -uS -H16 -S63 #{file}"
  end
 
  def format_root_fs
    loop_device = "/dev/loop0"
    begin
      FileUtils::sudo "losetup -o #{root_fs_offset} #{loop_device} #{file}"
      FileUtils::sudo "mke2fs -L #{root_fs_label} -jqF #{loop_device} #{root_fs_block_size}"
    ensure
      FileUtils::sudo "losetup -d #{loop_device}"
    end
  end

  def format_boot_fs
    loop_device = "/dev/loop0"
    begin
      FileUtils::sudo "losetup -o #{boot_fs_offset} #{loop_device} #{file}"
      FileUtils::sudo "mkdosfs -v -F 32 -n #{boot_fs_label} #{loop_device} #{boot_fs_block_size}"
    ensure
      FileUtils::sudo "losetup -d #{loop_device}"
    end
  end

  def mount_root_fs(&block)
    # TODO use a smarter mount_dir
    mount_dir = "/tmp/mount_root_fs"
    FileUtils::mkdir_p mount_dir

    begin
      FileUtils::sudo "mount -o loop,offset=#{root_fs_offset} #{file} #{mount_dir}"
      yield mount_dir
    ensure
      FileUtils::sudo "umount #{mount_dir}"
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

  def sync_root_fs
    mount_root_fs do |mount_dir|
      FileUtils::sudo "rsync -a --delete --exclude='boot/**' #{boot.root}/ #{mount_dir}"
    end
    FileUtils.touch file
  end

  def sync_boot_fs
    mount_boot_fs do |mount_dir|
      FileUtils::sudo "rsync -a --delete #{boot.root}/boot/ #{mount_dir}"
    end
    FileUtils.touch file
  end

  def install_syslinux_files(options = {})
    root = (options[:root] or "LABEL=#{root_fs_label}")
    version = (options[:version] or Time.now.strftime("%Y%m%d%H%M"))

    boot.image do |image|
      image.mkdir "/boot/"

      image.open("/boot/syslinux.cfg") do |f|
        f.puts "default linux"
        f.puts "label linux"
        f.puts "kernel #{readlink_boot_file('vmlinuz')}"
        f.puts "append ro root=#{root} initrd=#{readlink_boot_file('initrd.img')}"
      end
    end
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

  def root_fs_block_size
    linux_partition_info = `/sbin/sfdisk -l #{file}`.scan(%r{#{file}.*Linux}).first
    linux_partition_info.split[4].to_i
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

  def boot_fs_sector_count
    (120 * 1008) - free_sectors # end of partition on a multiple of 1008 (cylinder size)
  end

  def root_fs_offset
    (free_sectors + boot_fs_sector_count) * 512
  end

  def root_fs_label
    "root"
  end

  def boot_fs_label
    "boot"
  end

end
