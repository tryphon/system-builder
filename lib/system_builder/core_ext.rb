class Numeric

  def megabytes
    self * 1024 * 1024
  end
  alias_method :megabyte, :megabytes

  def in_megabytes
    self.to_f / 1.megabyte
  end

end

class Object

  def blank?
    false
  end

end

class NilClass 

  def blank?
    true
  end

end

class Array 

  alias_method :blank?, :empty?

end

class String

  alias_method :blank?, :empty?

end

# require 'rake/file_utils'

module FileUtils

  def sh(*cmd)
    options = Hash === cmd.last ? cmd.pop : {}
    puts "* #{cmd.join(' ')}"
    raise "Command failed: #{$?}" unless system(cmd.join(' '))
  end
  module_function :sh

  def sudo(*cmd)
    sh ["sudo", *cmd]
  end
  module_function :sudo

end

class Object
  def self.delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
    end
    prefix, to, allow_nil = options[:prefix], options[:to], options[:allow_nil]
    if prefix == true && to.to_s =~ /^[^a-z_]/
      raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
    end
    method_prefix =
      if prefix
        "#{prefix == true ? to : prefix}_"
      else
        ''
      end
    file, line = caller.first.split(':', 2)
    line = line.to_i
    methods.each do |method|
      method = method.to_s
      if allow_nil
        module_eval(<<-EOS, file, line - 2)
def #{method_prefix}#{method}(*args, &block) # def customer_name(*args, &block)
if #{to} || #{to}.respond_to?(:#{method}) # if client || client.respond_to?(:name)
#{to}.__send__(:#{method}, *args, &block) # client.__send__(:name, *args, &block)
end # end
end # end
EOS
      else
        exception = %(raise "#{self}##{method_prefix}#{method} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}")
        module_eval(<<-EOS, file, line - 1)
def #{method_prefix}#{method}(*args, &block) # def customer_name(*args, &block)
#{to}.__send__(:#{method}, *args, &block) # client.__send__(:name, *args, &block)
rescue NoMethodError # rescue NoMethodError
if #{to}.nil? # if client.nil?
#{exception} # # add helpful message to the exception
else # else
raise # raise
end # end
end # end
EOS
      end
    end
  end
end
