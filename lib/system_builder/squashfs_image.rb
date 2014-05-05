module SquashfsImage
  def make_squashfs(file)
    compression = "-comp xz" if boot.version == :wheezy

    FileUtils::sudo "mksquashfs #{boot.root}/ #{file} #{compression} -no-progress -noappend -e #{boot.root}/boot"
    FileUtils::sudo "chown #{ENV['USER']} #{file} && chmod +r #{file}"
  end
end
