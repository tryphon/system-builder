require 'tempfile'

class SystemBuilder::DiskSquashfsImage

  attr_accessor :boot, :size
  attr_reader :file

  def initialize(file)
    @file = file
    @size = 512.megabytes
  end

  def create
    boot.configurators << SystemBuilder::InitRamFsConfigurator.new
    boot.create

    file_creation = (not File.exists?(file))
    if file_creation
      create_file
      create_partition_table

      format_boot_fs
    end

    sync_boot_fs
    install_extlinux_files

    compress_root_fs
    install_extlinux
    compute_checksums

    self
  end

  def create_file
    FileUtils::mkdir_p File.dirname(file)
    FileUtils::sh "dd if=/dev/zero of=#{file} count=#{size.in_megabytes.to_i} bs=1M"
  end

  def create_partition_table
    # Partition must be bootable for syslinux
    FileUtils::sh "echo '#{free_sectors},,L,*' | /sbin/sfdisk --force --no-reread -uS -H16 -S63 #{file}"
  end
 
  def format_boot_fs
    loop_device = "/dev/loop0"
    begin
      FileUtils::sudo "losetup -o #{boot_fs_offset} #{loop_device} #{file}"
      FileUtils::sudo "mke2fs -L #{fs_label} -jqF #{loop_device} #{boot_fs_block_size}"
    ensure
      FileUtils::sudo "losetup -d #{loop_device}"
    end
  end

  def mount_boot_fs(mount_dir = "/tmp/mount_boot_fs", &block)
    FileUtils::mkdir_p mount_dir

    begin
      FileUtils::sudo "mount -o loop,offset=#{boot_fs_offset} #{file} #{mount_dir}"
      yield mount_dir
    ensure
      retries = 2
      begin
        FileUtils::sudo "umount #{mount_dir}"
      rescue
        if (retries -= 1) > 0
          sleep 3
          retry 
        end
      end
    end
  end

  attr_accessor :build_dir

  def build_dir
    @build_dir ||= "build"
  end 

  def squashfs_file
    "#{build_dir}/filesystem.squashfs"
  end

  def compress_root_fs
    FileUtils::sudo "mksquashfs #{boot.root}/ #{squashfs_file} -noappend -e #{boot.root}/boot"
    FileUtils::sudo "chown #{ENV['USER']} #{squashfs_file} && chmod +r #{squashfs_file}"
    
    mount_boot_fs do |mount_dir|
      FileUtils::sudo "cp #{squashfs_file} #{mount_dir}/filesystem.squashfs"
    end
    FileUtils.touch file
  end
  
  def sync_boot_fs
    mount_boot_fs do |mount_dir|
      FileUtils::sudo "rsync -a --delete #{boot.root}/boot/ #{mount_dir}/"
      FileUtils::sudo "ln -s #{readlink_boot_file('initrd.img')} #{mount_dir}/initrd.img"
      FileUtils::sudo "ln -s #{readlink_boot_file('vmlinuz')} #{mount_dir}/vmlinuz"
    end
    FileUtils.touch file
  end

  def install_extlinux_files(options = {})
    root = (options[:root] or "LABEL=#{fs_label}")
    version = (options[:version] or Time.now.strftime("%Y%m%d%H%M"))

    mount_boot_fs do |mount_dir|
      SystemBuilder::DebianBoot::Image.new(mount_dir).tap do |image|
        image.open("extlinux.conf") do |f|
          f.puts "DEFAULT linux"
          f.puts "LABEL linux"
          f.puts "SAY Now booting #{version} from syslinux ..."
          f.puts "KERNEL /vmlinuz"
          f.puts "APPEND ro initrd=/initrd.img boot=local root=/boot/filesystem.squashfs rootflags=loop rootfstype=squashfs rootdelay=6"
        end
      end
    end
  end

  def install_extlinux
    mount_boot_fs("#{boot.root}/boot") do 
      boot.chroot do |chroot|
        chroot.sudo "extlinux --install -H16 -S63 /boot"
      end
    end
    FileUtils::sh "dd if=#{boot.root}/usr/lib/syslinux/mbr.bin of=#{file} conv=notrunc"
  end

  def compute_checksums
    mount_boot_fs do |mount_dir|
      FileUtils::cd("#{mount_dir}") do
        FileUtils::sh"md5sum * |sudo tee MD5SUM"
      end 
    end
  end

  def fs_label
    "boot"
  end

  def readlink_boot_file(boot_file)
    File.basename(%x{readlink #{boot.root}/#{boot_file}}.strip)
  end

  def free_sectors
    64
  end

  def boot_fs_offset
    free_sectors * 512
  end

  def boot_fs_block_size
    linux_partition_info = `/sbin/sfdisk -l #{file}`.scan(%r{#{file}.*Linux}).first
    linux_partition_info.split[5].to_i
  end

end
