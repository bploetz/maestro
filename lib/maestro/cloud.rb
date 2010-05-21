require "ftools"
require "maestro/role"
require "maestro/node"
require 'maestro/validator'
require "net/ssh/multi"
require "log4r"
require "maestro/log4r/console_formatter"
require "maestro/log4r/file_formatter"


module Maestro
  # A named cloud (i.e. production, staging, test, dev, etc)
  module Cloud
    class Base
      include Validator

      # the name of this cloud
      attr_reader :name
      # the config file for this cloud
      attr_accessor :config_file
      # the Hash of Configurable Nodes in this Cloud
      attr_reader :configurable_nodes
      # String containing the full path to this Cloud's log directory
      attr_reader :log_directory
      dsl_property :keypair_name, :keypair_file

      # Creates a new Cloud object.
      # * name: the name of the Cloud
      # * cfg_file: Pointer to the file containing the Cloud configuration (optional)
      # * block: contents of the Cloud
      def initialize(name, cfg_file=nil, &block)
        super()
        raise StandardError, "Cloud name cannot contain spaces: #{name}" if name.is_a?(String) && !name.index(/\s/).nil?
        @name = name
        @config_file = cfg_file
        @roles = Hash.new
        @nodes = Hash.new
        @configurable_nodes = Hash.new
        @valid = true
        @logger = Log4r::Logger.new(Regexp::quote(@name.to_s))
        outputter = Log4r::StdoutOutputter.new("#{@name.to_s}-stdout")
        outputter.formatter = ConsoleFormatter.new
        @logger.add(outputter)
        init_logs
        instance_eval(&block) if block_given?
      end

      # Creates a Cloud from the contents of the given file
      def self.create_from_file(config_file)
        cloud = eval(File.read(config_file))
        cloud.config_file = config_file
        return cloud
      end

      # creates the Roles for this Cloud if a block is given. Otherwise, returns the roles Hash
      def roles(&block)
        if block_given?
          instance_eval(&block)
        else
          @roles
        end
      end

      # sets the roles Hash
      def roles=(roles)
        @roles = roles
      end

      # creates a Role
      def role(name, &block)
        if @roles.has_key?(name)
          invalidate "Duplicate role definition: #{name}"
        else
          @roles[name] = Role.new(name, self, &block)
        end
      end

      # creates the Nodes for this Cloud if a block is given, otherwise returns the Nodes in this Cloud
      def nodes(&block)
        if block_given?
          instance_eval(&block)
        else
          @nodes
        end
      end

      # sets the nodes Hash
      def nodes=(nodes)
        @nodes = nodes
      end

      def method_missing(name, *params) #:nodoc:
        @valid = false
        @validation_errors << "Unexpected attribute: #{name}"
      end

      # Reports the current status of this Cloud
      def status
        @logger.info "#{@name} Cloud status:"
        node_statuses
      end

      # Starts this Cloud. Takes no action if the Cloud is already running as currently configured
      def start
        @logger.info "Starting #{@name} Cloud. This may take a few minutes..."
      end

      # Configures the Nodes in this Cloud
      def configure
        @logger.info "Configuring #{@name} Cloud"
        if !@configurable_nodes.empty?
          session = open_ssh_session
          result = chef_solo_installed?(session)
          if !result[0]
            names = result[1].collect {|n| n.name}
            @logger.progress "Installing chef-solo on Nodes #{names.inspect}. This may take a few minutes..."
            session.close
            session = open_ssh_session(result[1])
            install_chef_solo(session)
            configure_chef_solo(session)
            session.close
            @logger.progress "\n"
          else
            @logger.info "chef-solo already installed on Nodes #{@configurable_nodes.keys.inspect}"
          end
          @logger.info "Running chef-solo on Nodes #{@configurable_nodes.keys.inspect}..."
          session = open_ssh_session
          run_chef_solo(session)
          session.close
          @logger.info "Configuration of #{@name} Cloud complete"
        end
      end

      # Checks if chef-solo is installed on each of the Configurable Nodes in this Cloud.
      # This method returns an Array with two elements:
      # * element[0] boolean indicating whether chef-solo is installed on all Configurable Nodes 
      # * element[1] Array of Nodes which need chef-solo installed
      def chef_solo_installed?(session=nil)
        close_session = false
        if session.nil?
          session = open_ssh_session
          close_session = true
        end
        @logger.info "Checking for installation of chef-solo..."
        valid = true
        needs_chef = Array.new
        session.open_channel do |channel|
          # Find the node for this channel's host
          the_node = nil
          @configurable_nodes.each_pair {|name, node| the_node = node if channel[:host].eql? node.hostname}
          if the_node.nil?
            @logger.error "Could not find node matching hostname #{channel[:host]}. This should not happen."
          else
            channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
            channel.exec("chef-solo --version") do |ch, success|
              ch.on_data do |ch, data|
                if !data.include?("Chef: 0.8")
                  valid = false
                  needs_chef << the_node
                end
              end
            end
          end
        end
        session.loop(60)
        session.close if close_session
        return [valid, needs_chef]
      end

      # installs chef-solo on the Configurable Nodes the given session is set up with
      def install_chef_solo(session=nil)
        close_session = false
        if session.nil?
          session = open_ssh_session
          close_session = true
        end
        etc_issue = nil
        session.open_channel do |channel|
          channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
          channel.exec("cat /etc/issue") do |ch, success|
            ch.on_data {|ch, data| etc_issue = data}
          end
        end
        session.loop(60)

        # shut off the stdout outputter and only log to the nodes' log files
        @configurable_nodes.each_pair {|name, node| node.disable_stdout}
        os = Maestro::OperatingSystem.create_from_etc_issue(etc_issue)
        os.chef_install_script.each do |cmd|
          session.open_channel do |channel|
            # Find the node for this channel's host
            the_node = nil
            @configurable_nodes.each_pair {|name, node| the_node = node if channel[:host].eql? node.hostname}
            if the_node.nil?
              @logger.error "Could not find node matching hostname #{channel[:host]}. This should not happen."
            else
              the_node.logger.info "Installing chef-solo"
              channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
              channel.exec(cmd) do |ch, success|
                @logger.progress "."
                ch.on_data {|ch, data| the_node.logger.info data}
                ch.on_extended_data {|ch, data| the_node.logger.error }
              end
            end
          end
          session.loop(60)
        end
        # turn the stdout outputter back on
        @configurable_nodes.each_pair {|name, node| node.enable_stdout}
        session.close if close_session
      end

      # configures chef-solo
      def configure_chef_solo(session=nil)
        close_session = false
        if session.nil?
          session = open_ssh_session
          close_session = true
        end
        # write the chef-solo config file
        chef_solo_config = 
          ["sudo rm /tmp/chef-solo.rb",
           "sudo mkdir -p /tmp/chef-solo",
           "sudo mkdir -p /tmp/chef-solo/cookbooks",
           "sudo mkdir -p /tmp/chef-solo/roles",
           "sudo sh -c 'echo file_cache_path \\\"/tmp/chef-solo\\\" >> /tmp/chef-solo.rb'",
           "sudo sh -c 'echo cookbook_path \\\"/tmp/chef-solo/cookbooks\\\" >> /tmp/chef-solo.rb'",
           "sudo sh -c 'echo role_path \\\"/tmp/chef-solo/roles\\\" >> /tmp/chef-solo.rb'"]
        chef_solo_config.each do |str|
          session.open_channel do |channel|
            channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
            channel.exec(str)
          end
          session.loop(60)
        end
        session.close if close_session
      end

      # runs chef-solo
      def run_chef_solo(session=nil)
        close_session = false
        if session.nil?
          session = open_ssh_session
          close_session = true
        end
        # shut off the stdout outputter and only log to the nodes' log files
        @configurable_nodes.each_pair {|name, node| node.disable_stdout}
        # clean up existing cookbooks and roles directories if they exist
        cleanup_cmds = 
          ["sudo rm -rf /tmp/chef-solo/cookbooks",
           "sudo rm -rf /tmp/chef-solo/roles",
           "sudo mkdir -p /tmp/chef-solo/cookbooks",
           "sudo mkdir -p /tmp/chef-solo/roles"]
        cleanup_cmds.each do |str|
          session.open_channel do |channel|
            channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
            channel.exec(str)
          end
          session.loop(60)
        end
        # run chef-solo
        chef_solo_commands = 
           ["sudo chef-solo -c /tmp/chef-solo.rb -r '#{chef_assets_url()}'"]
        chef_solo_commands.each do |cmd|
          session.open_channel do |channel|
            channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
            # Find the node for this channel's host
            the_node = nil
            @configurable_nodes.each_pair {|name, node| the_node = node if channel[:host].eql? node.hostname}
            if the_node.nil?
              @logger.error "Could not find node matching hostname #{channel[:host]}. This should not happen."
            else
              node_cmd = cmd + " -j '#{node_json_url(the_node)}'"
              channel.exec(node_cmd) do |ch, success|
                ch.on_data {|ch2, data2| the_node.logger.info data2}
                ch.on_extended_data {|ch2, data2| the_node.logger.error data2}
              end
            end
          end
          session.loop(60)
        end
        # turn the stdout outputter back on
        @configurable_nodes.each_pair {|name, node| node.enable_stdout}
        session.close if close_session
      end

      # Shuts down this Cloud. Takes no action if the Cloud is not running
      def shutdown
        @logger.info "Shutting down #{@name} Cloud"
      end


      protected

      # creates log directory and files for this cloud. If the log directory or files exist, no action is taken.
      def init_logs
        begin
          if !File.exists?(Maestro.maestro_log_directory)
            Maestro.create_log_dirs
            @logger.info "Created #{Maestro.maestro_log_directory}"
          end
          clouds_dir = Maestro.maestro_log_directory + "/clouds"
          if !File.exists?(clouds_dir)
            Dir.mkdir(clouds_dir)
            @logger.info "Created #{clouds_dir}"
          end
          cloud_dir = clouds_dir + "/#{@name}"
          if !File.exists?(cloud_dir)
            Dir.mkdir(cloud_dir)
            @logger.info "Created #{cloud_dir}"
          end
          @log_directory = cloud_dir
          cloud_log_file = cloud_dir + "/#{@name}.log"
          if !File.exists?(cloud_log_file)
            File.new(cloud_log_file, "a+")
            @logger.info "Created #{cloud_log_file}"
          end
          outputter = Log4r::FileOutputter.new("#{@name}-file", :formatter => FileFormatter.new, :filename => cloud_log_file, :truncate => false)
          @logger.add(outputter)
        rescue RuntimeError => rerr
          if !rerr.message.eql?("Maestro not configured correctly. Either RAILS_ROOT or ENV['MAESTRO_DIR'] must be defined")
            @logger.error "Unexpected Error"
            @logger.error rerr
          end
        rescue SystemCallError => syserr
          @logger.error "Error creating cloud directory"
          @logger.error syserr
        rescue StandardError => serr
          @logger.error "Unexpected Error"
          @logger.error serr
        end
      end

      # opens a multi ssh session. If the cnodes argument is nil, then a session
      # is opened up to each Configurable Node in this Cloud. Otherwise, a session
      # is opened to each Configurable Node in the cnodes array.
      def open_ssh_session(cnodes=[])
        handler = Proc.new do |server|
          server[:connection_attempts] ||= 0
          if server[:connection_attempts] < 6
            server[:connection_attempts] += 1
            the_node = nil
            @configurable_nodes.each_pair {|name, node| the_node = node if server.host.eql? node.hostname}
            if the_node.nil?
              @logger.error "Could not find node matching hostname #{server.host}. This should not happen."
              throw :go, :raise
            else
              @logger.info "Could not connect to Node #{the_node.name}. Trying again in 10 seconds..."
            end
            sleep 10
            throw :go, :retry
          else
            throw :go, :raise
          end
        end

        session = Net::SSH::Multi.start(:concurrent_connections => 10, :on_error => handler)
        if cnodes.empty?
          @configurable_nodes.each_pair {|node_name, node| session.use node.hostname, :user => node.ssh_user, :keys => [keypair_file]}
        else
          cnodes.each {|node| session.use node.hostname, :user => node.ssh_user, :keys => [keypair_file]}
        end
        return session
      end


      private

      # validates this Cloud
      def validate_internal
        invalidate "Missing keypair_name" if @keypair_name.nil?
        invalidate "Missing keypair_file" if @keypair_file.nil?
        validate_roles
        validate_nodes
      end

      # validates the roles in the cloud config
      def validate_roles
        if @roles.nil? || @roles.empty?
          invalidate "Missing roles"
        else
          @roles.each do |name, role|
            role.validate
            if !role.valid?
              role.validation_errors.each {|error_str| invalidate error_str}
            end
          end
        end
      end

      # validates the nodes in the cloud config
      def validate_nodes
        if @nodes.nil? || @nodes.empty?
          invalidate "Missing nodes"
        else
          @nodes.each do |name, node|
            node.validate
            if !node.valid?
              node.validation_errors.each {|error_str| invalidate error_str}
            end
          end
        end
      end
    end
  end
end
