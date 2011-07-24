require 'tempfile'

class SystemBuilder::IsoSquashfsImage

  attr_accessor :boot
  attr_reader :file

  def initialize(file)
    @file = file
  end

  def create
    boot.configurators << SystemBuilder::InitRamFsConfigurator.new
    boot.create

    compress_root_fs
    install_isolinux_files
    make_iso_fs

    self
  end

  def compress_root_fs
    unless File.exists?("build/filesystem.squashfs")
      FileUtils::sudo "mksquashfs #{boot.root}/ build/filesystem.squashfs -noappend -e /boot"
      FileUtils::sudo "chown #{ENV['USER']} build/filesystem.squashfs && chmod +r build/filesystem.squashfs"
    end
  end

  def install_isolinux_files(options = {})
    version = (options[:version] or Time.now.strftime("%Y%m%d%H%M"))

    boot.image do |image|
      image.mkdir "/boot/isolinux"

      image.open("/boot/isolinux/isolinux.cfg") do |f|
        f.puts "default linux"
        f.puts "label linux"
        f.puts "kernel /vmlinuz"
        f.puts "append ro initrd=/initrd.img boot=local root=/boot/filesystem.squashfs rootflags=loop rootfstype=squashfs"
      end

      image.install "/boot/isolinux", "/usr/lib/syslinux/isolinux.bin"
    end
  end

  def readlink_boot_file(boot_file)
    File.basename(%x{readlink #{boot.root}/#{boot_file}}.strip)
  end

  def make_iso_fs
    FileUtils::sudo "genisoimage -quiet -R -o #{file} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -graft-points vmlinuz=#{boot.root}/boot/#{readlink_boot_file('vmlinuz')} initrd.img=#{boot.root}/boot/#{readlink_boot_file('initrd.img')} filesystem.squashfs=build/filesystem.squashfs #{boot.root}/boot"
    FileUtils::sudo "chown $USER #{file}"
  end
  
end
