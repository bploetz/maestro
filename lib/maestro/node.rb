require "maestro/validator"
require "log4r"
require "maestro/log4r/console_formatter"
require "maestro/log4r/file_formatter"


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
      # the logger of this Node
      attr_accessor :logger

      # Creates a new Node
      def initialize(name, cloud, &block)
        super()
        raise StandardError, "Node name cannot contain spaces: #{name}" if name.is_a?(String) && !name.index(/\s/).nil?
        @name = name
        @cloud = cloud
        @logger = Log4r::Logger.new(Regexp::quote(@name.to_s))
        outputter = Log4r::StdoutOutputter.new("#{@name.to_s}-stdout")
        outputter.formatter = ConsoleFormatter.new
        @logger.add(outputter)
        init_logs
        instance_eval(&block) if block_given?
      end

      def method_missing(name, *params) #:nodoc:
        invalidate "Unexpected attribute: #{name}"
      end

      # disables the stdout Outputter and only logs to this Node's log file
      def disable_stdout
        stdoutoutputter = Log4r::Outputter["#{@name.to_s}-stdout"]
        stdoutoutputter.level = Log4r::OFF
      end

      # enables the stdout Outputter
      def enable_stdout
        stdoutoutputter = Log4r::Outputter["#{@name.to_s}-stdout"]
        stdoutoutputter.level = Log4r::ALL
      end


      protected

      # validates this Node
      def validate_internal
      end

      # creates log files for this cloud and all of its nodes. If the log files exist, no action is taken.
      def init_logs
        begin
          if !@cloud.log_directory.nil?
            node_log_file = @cloud.log_directory + "/#{@name.to_s}.log"
            if !File.exists?(node_log_file)
              File.new(node_log_file, "a+")
              @logger.info "Created #{node_log_file}"
            end
            outputter = Log4r::FileOutputter.new("#{@name.to_s}-file", :formatter => FileFormatter.new, :filename => node_log_file, :truncate => false)
            @logger.add(outputter)
          end
        rescue RuntimeError => rerr
          if !rerr.message.eql?("Maestro not configured correctly. Either RAILS_ROOT or ENV['MAESTRO_DIR'] must be defined")
            @logger.error "Unexpected Error"
            @logger.error rerr
          end
        rescue SystemCallError => syserr
          @logger.error "Error creating Node log file"
          @logger.error syserr
        rescue StandardError => serr
          @logger.error "Unexpected Error"
          @logger.error serr
        end
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
