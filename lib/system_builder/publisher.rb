module SystemBuilder
  class Publisher
    attr_accessor :box_name
    attr_accessor :build_server, :dist_directory, :www_server, :download_dir

    def initialize(box_name)
      @box_name = box_name

      @build_server = "dev.tryphon.priv"
      @dist_directory = "/var/lib/buildbot/dist"
      @www_server = "www.tryphon.priv"
      @download_dir = "/var/www/tryphon.eu/download"
    end

    def latest_attributes
      @latest_attributes ||= YAML.load(`ssh #{build_server} cat #{dist_directory}/#{box_name}/latest.yml`)
    end

    def release_name
      latest_attributes["name"]
    end

    def commit
      latest_attributes["commit"] or ENV['COMMIT']
    end

    def publish
      raise "Select a git commit with COMMIT=... (see buildbot at http://dev.tryphon.priv:8010/builders/#{box_name}/)" unless commit
      puts "Publish last release : #{release_name} (commit #{commit})"

      sh "scp '#{build_server}:#{dist_directory}/#{box_name}/#{release_name}*' #{build_server}:#{dist_directory}/#{box_name}/latest.yml #{www_server}:#{download_dir}/#{box_name}"
      sh "git tag -a #{release_name} -m 'Release #{release_name}' #{commit}"
      sh "git push --tags"
    end
  end
end
