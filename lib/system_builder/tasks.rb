require 'system_builder'
require 'system_builder/box_tasks'

module SystemBuilder

  def self.define_tasks(*arguments, &block)
    rake_files = Dir["#{File.expand_path('tasks')}/**/*.rake"]
    rake_files.each { |t| load t }

    options = Hash === arguments.last ? arguments.pop : {}
    names = arguments

    SystemBuilder::BoxTasks.multiple_boxes = (names.size > 1)

    names.each do |name|
      if options[:multiple_architecture]
        SystemBuilder::MultiArchBoxTasks.new(name, &block)
      else
        SystemBuilder::BoxTasks.new(name, &block)
      end
    end
  end

end
