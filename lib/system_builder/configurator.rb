module SystemBuilder

  class ProcConfigurator

    def initialize(proc = nil, &block)
      @proc = (proc or block)
    end

    def configure(chroot, options = {})
      @proc.call chroot
    end

  end

  class PuppetConfigurator

    attr_reader :manifest, :config

    def initialize(options = {})
      @manifest = (options.delete(:manifest) or ".")
      @config = options.dup
    end

    def puppet_directories
      %w{manifests files modules templates plugins}.collect { |d| "#{manifest}/#{d}" }.select { |d| File.directory?(d) }
    end

    def configure(chroot, options = {})
      debian_release = (options.delete(:debian_release) or :lenny)

      puts "* run puppet configuration"

      unless chroot.image.exists?("/etc/apt/sources.list.d/#{debian_release}-backports.list")
        chroot.image.open("/etc/apt/sources.list.d/#{debian_release}-backports.list") do |f|
          f.puts "deb http://backports.debian.org/debian-backports #{debian_release}-backports main contrib non-free"
        end

        chroot.image.open("/etc/apt/preferences") do |f|
          f.puts "Package: puppet"
          f.puts "Pin: release a=#{debian_release}-backports"
          f.puts "Pin-Priority: 999"
        end if debian_release == :lenny
        
        chroot.sudo "apt-get update"
      end

      chroot.apt_install :puppet, :rubygems
      chroot.image.open("/etc/default/puppet") do |f|
        f.puts "START=no"
      end

      unless File.directory?(manifest)
        chroot.image.install "/tmp/puppet.pp", manifest
        # chmod +r to make file readable for buildbot
        chroot.sudo "puppet --color=false tmp/puppet.pp 2>&1 | tee /tmp/puppet.log && chmod +r /tmp/puppet.log"
        process_log_file(chroot.image.expand_path("/tmp/puppet.log"))
      else
        context_dir = "/tmp/puppet"
        chroot.image.mkdir context_dir

        chroot.image.rsync context_dir, puppet_directories, :exclude => "*~", :delete => true

        chroot.image.open("#{context_dir}/manifests/config.pp") do |f|
          config.each do |key, value|
            f.puts "$#{key}=\"#{value}\""
          end
        end

        chroot.image.mkdir "#{context_dir}/config"
        chroot.image.open("#{context_dir}/config/fileserver.conf") do |f|
          %w{files plugins}.each do |mount_point|
            f.puts "[#{mount_point}]"
            f.puts "path #{context_dir}/#{mount_point}"
            f.puts "allow *"
          end
        end

        chroot.image.mkdir "#{context_dir}/tmp"

        debian_options = "export DEBIAN_SCRIPT_DEBUG=1;" if ENV['DEBIAN_SCRIPT_DEBUG']
        chroot.sudo "#{debian_options} puppet --color=false --modulepath '#{context_dir}/modules' --confdir='#{context_dir}/config' --templatedir='#{context_dir}/templates' --manifestdir='#{context_dir}/manifests' --vardir=#{context_dir}/tmp '#{context_dir}/manifests/site.pp' 2>&1 | tee #{context_dir}/puppet.log"

        process_log_file(chroot.image.expand_path("#{context_dir}/puppet.log"))
      end
    end

    def process_log_file(log_file)
      FileUtils.cp log_file, "puppet.log"
      unless File.readlines("puppet.log").grep(/^(err:|Could not parse for environment production)/).empty?
        raise "Error(s) during puppet configuration, see puppet.log file"
      end
    end

  end

end
