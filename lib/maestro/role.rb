require 'maestro/validator'

module Maestro
  # A role that a Node in a Cloud can play
  class Role
    include Validator

    # the name of this Role
    attr_reader :name
    # the Cloud this Role belongs to
    attr_reader :cloud
    dsl_property :public_ports

    def initialize(name, cloud, &block)
      super()
      raise StandardError, "Role name cannot contain spaces: #{name}" if name.is_a?(String) && !name.index(/\s/).nil?
      @name = name
      @cloud = cloud
      instance_eval(&block) if block_given?
    end

    private

    # validates this Role
    def validate_internal
      if !public_ports.nil?
        if !public_ports.instance_of? Array
          invalidate "'#{@name}' Role's public_ports attribute must be an Array (found #{public_ports.class})"
        else
          valid_ports = public_ports.all? {|port| port.instance_of? Fixnum}
          invalidate "'#{@name}' Role's public_ports attribute must be an Array of numbers" if !valid_ports
        end
      end
    end
  end
end
