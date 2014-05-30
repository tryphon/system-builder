class SystemBuilder::DebianBoot

  attr_accessor :version, :mirror, :architecture
  attr_accessor :exclude, :include, :components

  attr_reader :root
  attr_reader :configurators

  @@default_mirror = 'http://ftp.debian.org/debian'
  def self.default_mirror=(mirror)
    @@default_mirror = mirror
  end

  @@apt_proxy = nil
  def self.apt_proxy=(proxy)
    @@apt_proxy = proxy
  end
  def self.apt_proxy
    @@apt_proxy
  end

  def self.apt_options
    "-o Acquire::http::Proxy='#{apt_proxy}'" if apt_proxy
  end

  def mirror
    @mirror ||=
      if version == :lenny
        "http://archive.debian.org/debian"
      else
        @@default_mirror
      end
  end

  def initialize(root)
    @root = root

    @version = :lenny
    @architecture = :i386
    @components = ["main"]
    @exclude = []
    @include = [ "debian-archive-keyring" ]

    # kernel can't be installed by debootstrap
    @configurators =
      [ localhost_configurator,
        apt_configurator,
        kernel_configurator,
        fstab_configurator,
        timezone_configurator,
        resolvconf_configurator,
        policyrc_configurator
      ]
    @cleaners = [ apt_cleaner, policyrc_cleaner, tmp_cleaner ]
  end

  def create(force = false)
    return if @creating and not force

    bootstrap
    configure
    clean
    @creating = true
  end

  def bootstrap
    unless File.exists?(root)
      FileUtils::mkdir_p root
      FileUtils::sudo "debootstrap", debbootstrap_options, version, root, debbootstrap_url
    end
  end

  def configure
    puts "* #{configurators.size} configurators to run :"
    unless @configurators.empty?
      chroot do |chroot|
        @configurators.each do |configurator|
          configurator.configure chroot, :debian_release => version
        end
      end
    end
  end

  def clean
    unless @cleaners.empty?
      chroot do |chroot|
        @cleaners.each do |cleaner|
          cleaner.call(chroot)
        end
      end
    end
  end

  attr_accessor :kernel_version
  def kernel_version
    @kernel_version ||= "2.6"
  end

  def kernel_package_name
    package_names = Array(kernel_package_names)
    package_names.grep(kernel_version).first or package_names.first
  end

  def kernel_architecture
    architecture == :i386 ? "686" : architecture.to_s
  end

  def kernel_package_names
    case version
    when :lenny
      "linux-image-2.6-#{kernel_architecture}"
    when :squeeze
      ["linux-image-2.6-#{kernel_architecture}"].tap do |names|
        architecture_with_pae = architecture == :i386 ? "686-pae" : architecture.to_s
        names << "linux-image-3.2.0-0.bpo.4-#{architecture_with_pae}"
      end
    when :wheezy
      "linux-image-3.12-0.bpo.1-#{kernel_architecture}"
    else
      "linux-image-#{kernel_architecture}"
    end
  end

  def kernel_configurator
    SystemBuilder::ProcConfigurator.new do |chroot|
      puts "* install kernel"
      chroot.image.open("/etc/kernel-img.conf") do |f|
        f.puts "do_initrd = yes"
      end

      package_name = kernel_package_name

      options = {}
      options[:target_release] = "#{version}-backports" if package_name =~ /bpo/

      chroot.apt_install package_name, options
    end
  end

  def fstab_configurator
    SystemBuilder::ProcConfigurator.new do |chroot|
      puts "* create fstab"
      chroot.image.open("/etc/fstab") do |f|
        f.puts "LABEL=boot /boot auto defaults,noatime,ro 0 0"
        %w{/tmp /var/tmp}.each do |directory|
          f.puts "tmpfs #{directory} tmpfs defaults,noatime 0 0"
        end
        %w{/run /var/log}.each do |directory|
          f.puts "tmpfs #{directory} tmpfs defaults,noatime,mode=0755 0 0"
        end
      end unless chroot.image.exists?("/etc/fstab")
    end
  end

  def timezone_configurator
    SystemBuilder::ProcConfigurator.new do |chroot|
      puts "* define timezone"
      # Use same timezone than build machine
      chroot.image.install "/etc/", "/etc/timezone", "/etc/localtime"
    end
  end

  def resolvconf_configurator
    SystemBuilder::ProcConfigurator.new do |chroot|
      unless chroot.image.exists?("/etc/resolv.conf")
        puts "* define resolv.conf"
        # Use the same resolv.conf than build machine
        chroot.image.install "/etc/", "/etc/resolv.conf"
      end
    end
  end

  def apt_configurator
    AptConfigurator.new(self)
  end

  def apt_confd_proxy_file
    "/etc/apt/apt.conf.d/02proxy-systembuilder"
  end

  class AptConfigurator

    attr_reader :boot
    def initialize(boot)
      @boot = boot
    end

    def version
      @boot.version
    end

    def apt_proxy
      SystemBuilder::DebianBoot.apt_proxy
    end

    def apt_options
      SystemBuilder::DebianBoot.apt_options
    end

    def offline?
      ENV['OFFLINE'] == 'true'
    end

    def debbootstrap_url
      boot.debbootstrap_url
    end

    def mirror
      boot.mirror
    end

    def sources_list(chroot)
      File.readlines(chroot.image.file("/etc/apt/sources.list")).collect(&:strip)
    end

    def rewrite_sources_url(chroot)
      return unless apt_proxy

      chroot.image.open("/etc/apt/sources.list") do |f|
        sources_list(chroot).each do |line|
          f.puts line.gsub(/^deb #{debbootstrap_url}/, "deb #{mirror}")
        end
      end
    end

    def update(chroot)
      chroot.sudo "apt-get #{apt_options} update" unless offline?
    end

    def apt_confd_file
      boot.apt_confd_proxy_file
    end

    def configure_proxy(chroot)
      return unless apt_proxy

      chroot.image.open(apt_confd_file) do |f|
        f.puts "Acquire::http { Proxy \"#{apt_proxy}\"; };"
      end
    end

    def backports_list(chroot)
      backports_list_file = "/etc/apt/sources.list.d/#{version}-backports.list"
      return if chroot.image.exists? backports_list_file

      backports_url =
        case version
        when :lenny
          "http://archive.debian.org/debian-backports"
        when :squeeze
          "http://backports.debian.org/debian-backports"
        else
          # From wheezy-backports, backports are integrated in debian repositories
          mirror
        end

      chroot.image.open(backports_list_file) do |f|
        f.puts "deb #{backports_url} #{version}-backports main contrib non-free"
      end
    end

    def configure(chroot, options = {})
      rewrite_sources_url(chroot)
      backports_list(chroot)
      update(chroot)
      configure_proxy(chroot)
    end

  end

  def policyrc_configurator
    SystemBuilder::ProcConfigurator.new do |chroot|
      puts "* disable rc services"
      chroot.image.open("/usr/sbin/policy-rc.d") do |f|
        f.puts "exit 101"
      end
      chroot.sh "chmod +x /usr/sbin/policy-rc.d"
    end
  end

  def apt_cleaner
    Proc.new do |chroot|
      if chroot.image.exists?(apt_confd_proxy_file)
        puts "* remove apt proxy configuration"
        chroot.sudo "rm #{apt_confd_proxy_file}"
      end
      puts "* clean apt caches"
      chroot.sudo "apt-get clean"
      puts "* autoremove packages"
      chroot.sudo "apt-get autoremove --yes"

      puts "* Remove apt files"
      chroot.sudo "find /var/lib/apt/ /var/cache/apt -type f | xargs rm"
    end
  end

  def policyrc_cleaner
    Proc.new do |chroot|
      puts "* enable rc services"
      chroot.sh "rm /usr/sbin/policy-rc.d"
    end
  end

  def tmp_cleaner
    Proc.new do |chroot|
      puts "* Clean /tmp"
      chroot.sh "rm -rf /tmp/*"
    end
  end

  def localhost_configurator
    SystemBuilder::ProcConfigurator.new do |chroot|
      chroot.image.open("/etc/hosts") do |f|
        f.puts "127.0.0.1	localhost"
        f.puts "::1     localhost ip6-localhost ip6-loopback"
      end
    end
  end

  def debbootstrap_options
    {
      :arch => architecture,
      :exclude => exclude.join(','),
      :include => include.join(','),
      :variant => :minbase,
      :components => components.join(',')
    }.collect do |k,v|
      ["--#{k}", Array(v).join(',')] unless v.blank?
    end.compact
  end

  def debbootstrap_url
    if self.class.apt_proxy
      "#{self.class.apt_proxy}#{mirror.gsub('http:/','')}"
    else
      mirror
    end
  end

  def image(&block)
    @image ||= Image.new(root)

    if block_given?
      yield @image
    else
      @image
    end
  end

  def chroot(&block)
    @chroot ||= Chroot.new(image)
    @chroot.execute &block
  end

  class Image

    def initialize(root)
      @root = root
    end

    def mkdir(directory)
      FileUtils::sudo "mkdir -p #{expand_path(directory)}"
    end

    def install(target, *sources)
      FileUtils::sudo "cp --preserve=mode,timestamps #{sources.join(' ')} #{expand_path(target)}"
    end

    def rsync(target, *sources)
      sources = sources.flatten
      options = (Hash === sources.last ? sources.pop : {})
      rsync_options = options.collect { |k,v| v == true ? "--#{k}" : "--#{k}='#{v}'" }
      FileUtils::sudo "rsync -a #{rsync_options.join(' ')} #{sources.join(' ')} #{expand_path(target)}"
    end

    def open(filename, &block)
      Tempfile.open(File.basename(filename)) do |f|
        yield f
        f.close

        File.chmod 0644, f.path
        install filename, f.path
      end
    end



    def expand_path(path)
      File.join(@root,path)
    end
    alias_method :file, :expand_path

    def exists?(path)
      path = expand_path(path)
      File.exists?(path) or File.symlink?(path)
    end

  end

  class Chroot

    attr_reader :image

    def initialize(image)
      @image = image
    end

    def apt_install(*packages)
      options = {}
      if packages.last.is_a?(Hash)
        options = packages.pop
      end

      options_cmd_line = options.map do |k,v|
        part = "--#{k.to_s.gsub('_','-')}"
        part += "=#{v}" if v != true
        part
      end.join(' ')

      sudo "apt-get install #{SystemBuilder::DebianBoot.apt_options} #{options_cmd_line} --yes --force-yes #{packages.join(' ')}"
    end

    def cp(*arguments)
      sudo "cp #{arguments.join(' ')}"
    end

    def sh(*arguments)
      FileUtils::sudo "chroot #{image.expand_path('/')} sh -c \"export HOME=/root; LC_ALL=C #{arguments.join(' ')}\""
    end
    alias_method :sudo, :sh

    def execute(&block)
      begin
        prepare_run
        yield self
      ensure
        unprepare_run
      end
    end

    def prepare_run
      FileUtils::sudo "mount proc #{image.expand_path('/proc')} -t proc"
    end

    def unprepare_run
      FileUtils::sudo "umount #{image.expand_path('/proc')}"
    end

  end

end
