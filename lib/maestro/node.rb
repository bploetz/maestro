require "maestro/validator"

module Maestro
  module Node
    # A node (i.e. a server, a machine, a vm, a device, etc...) in a cloud.
    class Base
      include Validator

      # the name of this Node
      attr_reader :name
      # the Cloud this Node is associated with
      attr_reader :cloud
      # the host name of this Node
      attr_accessor :hostname
      # the IP address of this Node
      attr_accessor :ip_address

      # Creates a new Node
      def initialize(name, cloud, &block)
        super()
        raise StandardError, "Node name cannot contain spaces: #{name}" if name.is_a?(String) && !name.index(/\s/).nil?
        @name = name
        @cloud = cloud
        instance_eval(&block) if block_given?
      end

      def method_missing(name, *params) #:nodoc:
        invalidate "Unexpected attribute: #{name}"
      end

      protected

      # validates this Node
      def validate_internal
      end
    end


    # A node which is able to be SSH'd into to be configured by Maestro with Chef
    class Configurable < Base

      DEFAULT_SSH_USER = "root"

      dsl_property :roles, :ssh_user
      # the file name of this Configurable Node's Chef Node JSON file
      attr_accessor :json_filename
      # the contents of this Configurable Node's Chef Node JSON file
      attr_accessor :json

      # Creates a new Configurable Node
      def initialize(name, cloud, &block)
        super(name, cloud, &block)
        @json_filename = cloud.name.to_s + "-" + name.to_s + ".json"
        @json = "{ \"run_list\": ["
        if !@roles.nil? && !@roles.empty?
          @roles.each {|role_name| @json = @json + "\"role[#{role_name.to_s}]\", "}
          @json.chop! if @json =~ /\s$/
          @json.chop! if @json =~ /,$/
        end
        @json = @json + "]}"
      end

      protected

      # validates this Configurable
      def validate_internal
        super
        invalidate "'#{@name}' Node missing roles map" if roles.nil?
      end
    end

  end
end
