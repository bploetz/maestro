require "maestro/role"
require "maestro/node"
require 'maestro/validator'
require "net/ssh/multi"


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
        puts "#{@name} Cloud status:"
        node_statuses
      end

      # Starts this Cloud. Takes no action if the Cloud is already running as currently configured
      def start
        puts "Starting #{@name} Cloud. This may take a few minutes..."
      end

      # Configures the Nodes in this Cloud
      def configure
        puts "Configuring #{@name} Cloud"
        session = open_ssh_session
        if !chef_solo_installed?(session)
          puts "Installing chef-solo. This may take a few minutes..."
          install_chef_solo(session)
          configure_chef_solo(session)
        else
          puts "chef-solo already installed"
        end
        puts "Running chef-solo..."
        run_chef_solo(session)
        session.close
      end

      # Returns true if chef-solo is installed and the correct version, false if not
      def chef_solo_installed?(session=nil)
        close_session = false
        if session.nil?
          session = open_ssh_session
          close_session = true
        end
        puts "Checking for installation of chef-solo..."
        valid = false
        session.open_channel do |channel|
          channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
          channel.exec("chef-solo --version") do |ch, success|
            ch.on_data {|ch, data| valid = true if data.include?("Chef: 0.8")}
          end
        end
        session.loop
        session.close if close_session
        return valid
      end

      # installs chef-solo on each Configurable Node in the cloud
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
        session.loop

        os = Maestro::OperatingSystem.create_from_etc_issue(etc_issue)
        os.chef_install_script.each do |cmd|
          session.open_channel do |channel|
            channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
            channel.exec(cmd) do |ch, success|
              ch.on_data {|ch, data| puts data}
              ch.on_extended_data {|ch, data| puts "ERROR: #{data}"}
            end
          end
          session.loop
        end
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
          session.loop
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
        commands = 
           ["sudo chef-solo -c /tmp/chef-solo.rb -r '#{chef_assets_url()}'"]
        commands.each do |cmd|
          session.open_channel do |channel|
            channel.request_pty {|ch, success| abort "could not obtain pty" if !success}
            # Find the node for this channel's host
            the_node = nil
            @configurable_nodes.each_pair {|name, node| the_node = node if channel[:host].eql? node.hostname}
            if the_node.nil?
              puts "ERROR! Could not find node matching hostname #{channel[:host]}. This should not happen."
            else
              node_cmd = cmd + " -j '#{node_json_url(the_node)}'"
              channel.exec(node_cmd) do |ch, success|
                ch.on_data {|ch2, data2| puts "#{data2}"}
                ch.on_extended_data {|ch2, data2| puts "#{data2}"}
              end
            end
          end
          session.loop
        end
        session.close if close_session
      end

      # Shuts down this Cloud. Takes no action if the Cloud is not running
      def shutdown
        puts "Shutting down #{@name} Cloud"
      end


      protected

      # opens a multi ssh session to all of the nodes in the Cloud
      def open_ssh_session
        handler = Proc.new do |server|
          server[:connection_attempts] ||= 0
          if server[:connection_attempts] < 50
            server[:connection_attempts] += 1
            sleep 2
            throw :go, :retry
          else
            throw :go, :raise
          end
        end

        session = Net::SSH::Multi.start(:on_error => handler)
        @configurable_nodes.each_pair {|node_name, node| session.use node.hostname, :user => node.ssh_user, :keys => [keypair_file]}
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
