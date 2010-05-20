require "AWS"
require "aws/s3"
require "maestro/role"


# disable "warning: peer certificate won't be verified in this SSL session" messages
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end


module Maestro
  module Cloud
    # Amazon Web Services cloud
    class Aws < Base

      MAESTRO_NODE_PREFIX = "node."
      MAESTRO_ROLE_PREFIX = "role."
      MAESTRO_DEFAULT_ROLE = "default"

      # Array of all ec2 security groups names in this Cloud
      attr_reader :ec2_security_groups
      # Array of ec2 security group names for the Roles in this Cloud
      attr_reader :role_ec2_security_groups
      # Array of ec2 security group names for the Maestro::Node::Aws::Ec2 Nodes in this Cloud
      attr_reader :node_ec2_security_groups
      # the default ec2 security group name for this Cloud
      attr_reader :default_ec2_security_group
      # Array of all rds db parameter group names in this Cloud
      attr_reader :db_parameter_groups
      # Array of all rds db security group names in this Cloud
      attr_reader :db_security_groups
      # Hash of Ec2 Nodes
      attr_reader :ec2_nodes
      # Hash of Elb Nodes
      attr_reader :elb_nodes
      # Hash of Rds Nodes
      attr_reader :rds_nodes
      dsl_property :aws_account_id, :aws_access_key, :aws_secret_access_key, :chef_bucket

      def initialize(name, cfg_file=nil, &block)
        @ec2_nodes = Hash.new
        @elb_nodes = Hash.new
        @rds_nodes = Hash.new
        super(name, cfg_file, &block)
        @ec2_security_groups = Array.new
        @role_ec2_security_groups = Array.new
        @node_ec2_security_groups = Array.new
        @default_ec2_security_group = role_ec2_security_group_name(MAESTRO_DEFAULT_ROLE)
        @role_ec2_security_groups << @default_ec2_security_group
        @ec2_nodes.values.each {|ec2| ec2.set_default_security_group(@default_ec2_security_group)}
        @db_parameter_groups = Array.new
        @db_security_groups = Array.new
        @rds_nodes.values.each do |rds|
          @db_parameter_groups << rds.db_parameter_group_name
          @db_security_groups << rds.db_security_group_name
        end
      end

      # creates a Maestro::Node::Aws::Ec2 Node
      def ec2_node(name, &block)
        if @nodes.has_key?(name)
          invalidate "Duplicate node definition: #{name}"
        else
          ec2 = Maestro::Node::Aws::Ec2.new(name, self, &block)
          @nodes[name] = ec2
          @ec2_nodes[name] = ec2
          @configurable_nodes[name] = ec2
        end
      end

      # creates a Maestro::Node::Aws::Elb Node
      def elb_node(name, &block)
        if @nodes.has_key?(name)
          invalidate "Duplicate node definition: #{name}"
        else
          elb = Maestro::Node::Aws::Elb.new(name, self, &block)
          @nodes[name] = elb
          @elb_nodes[name] = elb
        end
      end

      # creates a Maestro::Node::Aws::Rds Node
      def rds_node(name, &block)
        if @nodes.has_key?(name)
          invalidate "Duplicate node definition: #{name}"
        else
          rds = Maestro::Node::Aws::Rds.new(name, self, &block)
          @nodes[name] = rds
          @rds_nodes[name] = rds
        end
      end

      # establishes a connection to Amazon
      def connect!
        @ec2 = AWS::EC2::Base.new(:access_key_id => aws_access_key, :secret_access_key => aws_secret_access_key, :use_ssl => true)
        @elb = AWS::ELB::Base.new(:access_key_id => aws_access_key, :secret_access_key => aws_secret_access_key, :use_ssl => true)
        @rds = AWS::RDS::Base.new(:access_key_id => aws_access_key, :secret_access_key => aws_secret_access_key, :use_ssl => true)
        s3_logger = Logger.new(STDOUT)
        s3_logger.level = Logger::FATAL
        AWS::S3::Base.establish_connection!(:access_key_id => aws_access_key, :secret_access_key => aws_secret_access_key, :use_ssl => true)
      end

      # Reports the current status of this Cloud
      def status
        connect!
        super
      end

      # Starts this Cloud. Takes no action if the Cloud is already running as currently configured
      def start
        connect!
        super
        ensure_rds_security_groups if !@rds_nodes.empty?
        ensure_rds_db_parameter_groups if !@rds_nodes.empty?
        ensure_ec2_security_groups if !@ec2_nodes.empty?
        ensure_rds_db_security_groups if !@rds_nodes.empty?
        ensure_nodes_running
        ensure_elastic_ips if !@ec2_nodes.empty?
        ensure_ebs_volumes if !@ec2_nodes.empty?
      end

      # Configures the Nodes in this Cloud
      def configure
        connect!
        get_configurable_node_hostnames
        upload_chef_assets
        super
      end

      # Updates this Cloud based on the current configuration
      def update
        connect!
        super
        # TODO:
        # Need to account for @elb.enable_availability_zones_for_load_balancer
        # in update if the availability zones of ec2 instances added/removed from
        # the lb changes the zones. ADD TESTS FOR THIS WORKFLOW!
      end

      # Shuts down this Cloud. Takes no action if the Cloud is not running
      def shutdown
        connect!
        super
        ensure_nodes_terminated
      end

      # Reboots the given Rds Node
      def reboot_rds_node(node_name)
        to_be_watched = Array.new
        node = @rds_nodes[node_name]
        @logger.info "Rebooting Node #{node_name}..."
        @rds.reboot_db_instance(:db_instance_identifier => node.db_instance_identifier)
        to_be_watched << node_name
        STDOUT.sync = true
        @logger.progress "Waiting for Node #{node_name} to reboot. This may take several minutes..."
        while !to_be_watched.empty?
          instances =  @rds.describe_db_instances
          instance = find_rds_node_instance(node.db_instance_identifier, instances)
          if !instance.nil? && instance.DBInstanceStatus.eql?("available")
            @logger.info ""
            @logger.info "Node #{node_name} rebooted"
            to_be_watched.delete(node_name)
          elsif !instance.nil? && instance.DBInstanceStatus.eql?("failed")
            @logger.info ""
            @logger.info "Node #{node_name} failed to reboot!"
            to_be_watched.delete(node_name)
          else
            @logger.progress "."
          end
          sleep 5 if !to_be_watched.empty?
        end
      end

      # Reports the current status of all Nodes in this Cloud
      def node_statuses
        elb_node_statuses if !@elb_nodes.empty?
        ec2_node_statuses if !@ec2_nodes.empty?
        rds_node_statuses if !@rds_nodes.empty?
      end

      # Reports the current status of all Rds Nodes in this Cloud
      def rds_node_statuses
        all_instances = @rds.describe_db_instances
        @rds_nodes.each_pair do |node_name, node|
          node_instance = find_rds_node_instance(node_name, all_instances)
          if node_instance.nil?
            @logger.info "  #{node_name}: not running"
          else
            @logger.info "  #{node_name}: #{node_instance.DBInstanceStatus} (host: #{node_instance.Endpoint.Address}, port: #{node_instance.Endpoint.Port})"
          end
        end
      end

      # Reports the current status of all Ec2 Nodes in this Cloud
      def ec2_node_statuses
        all_instances = @ec2.describe_instances
        @ec2_nodes.each_pair do |node_name, node|
          node_instance = find_ec2_node_instance(node_name, all_instances)
          if node_instance.nil?
            @logger.info "  #{node_name}: not running"
          else
            @logger.info "  #{node_name}: #{node_instance.instanceState.name} (instance #{node_instance.instanceId}, host: #{node_instance.dnsName})"
          end
        end
      end

      # Reports the current status of all Elb Nodes in this Cloud
      def elb_node_statuses
        all_balancers = @elb.describe_load_balancers
        @elb_nodes.each_pair do |node_name, node|
          node_balancer = find_elb_node_instance(node_name, all_balancers)
          if node_balancer.nil?
            @logger.info "  #{node_name}: not running"
          else
            @logger.info "  #{node_name}: running (host: #{node_balancer.DNSName})"
            @logger.info "  #{node_name} registered instances health:"
            health = @elb.describe_instance_health(:load_balancer_name => node.load_balancer_name)
            all_instances = @ec2.describe_instances
            node.ec2_nodes.each do |ec2_node_name|
              ec2_instance = find_ec2_node_instance(ec2_node_name, all_instances)
              ec2_node = @ec2_nodes[ec2_node_name]
              health_member = health.DescribeInstanceHealthResult.InstanceStates.member.select {|member| member if member.InstanceId.eql?(ec2_instance.instanceId)}
              @logger.info "  #{node_name.gsub(/./, ' ')} #{ec2_node_name}: #{health_member[0].State} (#{health_member[0].Description})"
            end
          end
        end
      end

      # finds the db instance instance tagged as the given node_name, or nil if not found
      def find_rds_node_instance(node_name, db_instances)
        node_instance = nil
        return node_instance if db_instances.nil? || db_instances.empty? || db_instances.DescribeDBInstancesResult.nil? || db_instances.DescribeDBInstancesResult.DBInstances.nil?
        db_instance = db_instances.DescribeDBInstancesResult.DBInstances.DBInstance
        if db_instance.is_a?(Array)
          db_instance.each {|db| node_instance = db if (db.DBInstanceIdentifier.eql?(node_name) && !db.DBInstanceStatus.eql?("deleted"))}
        elsif db_instance.is_a?(Hash)
          node_instance = db_instance if (db_instance.DBInstanceIdentifier.eql?(node_name) && !db_instance.DBInstanceStatus.eql?("deleted"))
        end
        node_instance
      end

      # finds the non-terminated ec2 instance tagged as the given node_name, or nil if not found
      def find_ec2_node_instance(node_name, instances)
        node_instance = nil
        return node_instance if instances.nil? || instances.empty? || instances.reservationSet.nil? || instances.reservationSet.item.nil? || instances.reservationSet.item.empty?
        tag = @ec2_nodes[node_name].node_security_group
        instances.reservationSet.item.each do |reservation|
          if reservation.groupSet.item.any? {|group| group.groupId.eql?(tag)}
            node_instance = reservation.instancesSet.item.detect {|instance| !instance.instanceState.name.eql?("terminated")}
          end
        end
        node_instance
      end

      # finds the load balancer instance tagged as the given node_name, or nil if not found
      def find_elb_node_instance(node_name, balancers)
        node = @elb_nodes[node_name]
        node_instance = nil
        return node_instance if node.nil? || balancers.nil? || balancers.empty? || balancers.DescribeLoadBalancersResult.nil? || balancers.DescribeLoadBalancersResult.LoadBalancerDescriptions.nil?
        balancers.DescribeLoadBalancersResult.LoadBalancerDescriptions.member.each do |desc|
          if desc.LoadBalancerName.eql?(node.load_balancer_name)
            node_instance = desc
          end
        end
        node_instance
      end

      # ensures that the EC2 security groups of this cloud are created and configured
      def ensure_ec2_security_groups
        # the default security group applied to all nodes
        ensure_ec2_security_group(@default_ec2_security_group)
        ensure_ec2_security_group_name_configuration(@default_ec2_security_group, @default_ec2_security_group, aws_account_id)
        ensure_ec2_security_group_cidr_configuration(@default_ec2_security_group, "22", "22", "tcp")
        # set up node groups
        @ec2_nodes.values.each do |node|
          ensure_ec2_security_group(node.node_security_group)
          @node_ec2_security_groups << node.node_security_group
        end
        # set up role groups
        role_groups = Hash.new
        @roles.keys.collect {|role_name| role_groups[role_name] = role_ec2_security_group_name(role_name)}
        role_groups.values.each {|group| ensure_ec2_security_group(group)}
        @role_ec2_security_groups = @role_ec2_security_groups + role_groups.values
        @roles.each_pair do |name, role|
          if !role.public_ports.nil? && !role.public_ports.empty?
            role.public_ports.each {|port| ensure_ec2_security_group_cidr_configuration(role_ec2_security_group_name(name), port, port, "tcp")}
          end
        end
        # collect all groups
        @ec2_security_groups = @ec2_security_groups + @node_ec2_security_groups
        @ec2_security_groups = @ec2_security_groups + @role_ec2_security_groups
      end

      # returns an ec2 security group name to tag an instance as being in a role, using the default naming convention
      def role_ec2_security_group_name(role_name)
        "#{@name}.#{MAESTRO_ROLE_PREFIX}#{role_name}"
      end

      # ensures that the nodes of this cloud are running
      def ensure_nodes_running
        ensure_rds_nodes if !@rds_nodes.empty?
        ensure_ec2_nodes if !@ec2_nodes.empty?
        ensure_elb_nodes if !@elb_nodes.empty?
      end

      # ensures that the Rds db parameter groups of this cloud are configured
      def ensure_rds_db_parameter_groups
        @rds_nodes.each_pair do |node_name, node|
          if !node.db_parameter_group_name.nil?
            begin
              group = @rds.describe_db_parameter_groups(:db_parameter_group_name => node.db_parameter_group_name)
              @logger.info "Node #{node.name}'s db parameter group already exists (#{node.db_parameter_group_name})"
            rescue AWS::Error => aws_error
              if aws_error.message.eql? "DBParameterGroup #{node.db_parameter_group_name} not found."
                @rds.create_db_parameter_group(:db_parameter_group_name => node.db_parameter_group_name, :engine => node.engine, :description => "The #{node.cloud.name} Cloud's #{node.name} Node's DB Parameter group")
                group = @rds.describe_db_parameter_groups(:db_parameter_group_name => node.db_parameter_group_name)
                @logger.info "Created db parameter group for Node #{node.name} (#{node.db_parameter_group_name})"
              else
                @logger.error "ERROR! Unexpected error retrieving db parameter groups: #{aws_error.message}"
              end
            end
            if !group.nil?
              # must modify the db param group 20 at a time.
              parameters = Array.new
              node.db_parameters.each do |p|
                parameters << {:name => p[:name], :value => p[:value], :apply_method => "pending-reboot"}
              end
              parameters.each_slice(20) do |slice|
                begin
                  @rds.modify_db_parameter_group(:db_parameter_group_name => node.db_parameter_group_name, :parameters => slice)
                rescue AWS::InvalidParameterValue => invalid_param
                  @logger.error "ERROR! #{invalid_param.message}"
                end
              end
              @logger.info "Updated Node #{node.name}'s db parameter group (#{node.db_parameter_group_name}). Changes will be reflected when the Node is next rebooted."
            end
          end
        end
      end

      # ensures that the Rds security groups of this cloud are configured
      def ensure_rds_db_security_groups
        @rds_nodes.each_pair do |node_name, node|
          begin
            group = @rds.describe_db_security_groups(:db_security_group_name => node.db_security_group_name)
            @logger.info "Node #{node.name}'s db security group already exists (#{node.db_security_group_name})"
          rescue AWS::Error => aws_error
            if aws_error.message.eql? "DBSecurityGroup #{node.db_security_group_name} not found."
              @rds.create_db_security_group(:db_security_group_name => node.db_security_group_name, :db_security_group_description => "The #{node.cloud.name} Cloud's #{node.name} Node's DB Security group")
              group = @rds.describe_db_security_groups(:db_security_group_name => node.db_security_group_name)
              @logger.info "Created db security group for Node #{node.name} (#{node.db_security_group_name})"
            else
              @logger.error "ERROR! Unexpected error retrieving db security groups: #{aws_error.message}"
            end
          end
          if !group.nil? && !@ec2_nodes.empty?
            if group.DescribeDBSecurityGroupsResult.DBSecurityGroups.DBSecurityGroup.EC2SecurityGroups.nil?
              @rds.authorize_db_security_group(:db_security_group_name => node.db_security_group_name, :ec2_security_group_name => @default_ec2_security_group, :ec2_security_group_owner_id => aws_account_id)
              @logger.info "Authorized network ingress from Nodes #{@ec2_nodes.keys.inspect} to Node #{node.name}"
            else
              @logger.info "Network ingress from Nodes #{@ec2_nodes.keys.inspect} to Node #{node.name} already authorized"
            end
          end
        end
      end

      # ensures that the Rds nodes of this cloud are running
      def ensure_rds_nodes
        all_instances =  @rds.describe_db_instances
        to_be_started = Array.new
        to_be_watched = Array.new
        @rds_nodes.each_pair do |node_name, node|
          node_instance = find_rds_node_instance(node.db_instance_identifier, all_instances)
          if node_instance.nil?
            @logger.info "Node #{node_name} not running. Starting..."
            to_be_started << node_name
          elsif node_instance.DBInstanceStatus.eql?("deleting")
            @logger.info "Node #{node_name} deleting. Re-creating..."
            to_be_started << node_name
          elsif (node_instance.DBInstanceStatus.eql?("creating"))
            @logger.info "Node #{node_name} starting up..."
            to_be_watched << node_name
          elsif (node_instance.DBInstanceStatus.eql?("rebooting"))
            @logger.info "Node #{node_name} rebooting..."
            to_be_watched << node_name
          elsif (node_instance.DBInstanceStatus.eql?("modifying"))
            @logger.info "Node #{node_name} being modified..."
            to_be_watched << node_name
          elsif (node_instance.DBInstanceStatus.eql?("resetting-mastercredentials"))
            @logger.info "Node #{node_name} resetting master credentials..."
            to_be_watched << node_name
          elsif (node_instance.DBInstanceStatus.eql?("available"))
            @logger.info "Node #{node_name} already running (host: #{node_instance.Endpoint.Address}, port: #{node_instance.Endpoint.Port})"
          elsif (node_instance.DBInstanceStatus.eql?("backing-up"))
            @logger.info "Node #{node_name} already running (host: #{node_instance.Endpoint.Address}, port: #{node_instance.Endpoint.Port})"
          elsif (node_instance.DBInstanceStatus.eql?("failed"))
            @logger.info "Node #{node_name} in a failed state (host: #{node_instance.Endpoint.Address}, port: #{node_instance.Endpoint.Port})"
          elsif (node_instance.DBInstanceStatus.eql?("storage-full"))
            @logger.info "Node #{node_name} in a failed state due to storage full (host: #{node_instance.Endpoint.Address}, port: #{node_instance.Endpoint.Port})"
          end
        end
        to_be_started.each do |node_name|
          node = @nodes[node_name]
          result = @rds.create_db_instance(:db_instance_identifier => node.db_instance_identifier, :allocated_storage => node.allocated_storage, :db_instance_class => node.db_instance_class, :engine => node.engine, :master_username => node.master_username, :master_user_password => node.master_user_password, :port => node.port, :availability_zone => node.availability_zone, :preferred_maintenance_window => node.preferred_maintenance_window, :backup_retention_period => node.backup_retention_period, :preferred_backup_window => node.preferred_backup_window)
          to_be_watched << node_name
        end
        STDOUT.sync = true
        @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to start. This may take several minutes..." if !to_be_watched.empty?
        while !to_be_watched.empty?
          instances =  @rds.describe_db_instances
          to_be_watched.each do |node_name|
            node = @nodes[node_name]
            instance = find_rds_node_instance(node.db_instance_identifier, instances)
            if !instance.nil? && instance.DBInstanceStatus.eql?("available")
              @logger.progress "\n"
              @logger.info "Node #{node_name} started (host: #{instance.Endpoint.Address}, port: #{instance.Endpoint.Port})"
              to_be_watched.delete(node_name)
              @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to start. This may take several minutes..." if !to_be_watched.empty?
            elsif !instance.nil? && instance.DBInstanceStatus.eql?("failed")
              @logger.progress "\n"
              @logger.info "Node #{node_name} failed to start!"
              to_be_watched.delete(node_name)
              @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to start. This may take several minutes..." if !to_be_watched.empty?
            else
              @logger.progress "."
            end
          end
          sleep 5 if !to_be_watched.empty?
        end
      end

      # ensures that the Ec2 nodes of this cloud are running
      def ensure_ec2_nodes
        all_instances =  @ec2.describe_instances()
        to_be_started = Array.new
        to_be_watched = Array.new
        @ec2_nodes.keys.each do |node_name|
          node_instance = find_ec2_node_instance(node_name, all_instances)
          if node_instance.nil?
            @logger.info "Node #{node_name} not running. Starting..."
            to_be_started << node_name
          elsif node_instance.instanceState.name.eql?("shutting-down")
            @logger.info "Node #{node_name} shutting down. Re-starting..."
          elsif node_instance.instanceState.name.eql?("pending")
            @logger.info "Node #{node_name} starting up..."
            to_be_watched << node_name
          else
            @logger.info "Node #{node_name} already running (instance #{node_instance.instanceId}, host: #{node_instance.dnsName})"
          end
        end
        to_be_started.each do |node_name|
          node = @nodes[node_name]
          @ec2.run_instances(:image_id => node.ami, :min_count => 1, :max_count => 1, :key_name => keypair_name, :instance_type => node.instance_type, :availability_zone => node.availability_zone, :security_group => node.security_groups)
          to_be_watched << node_name
        end
        STDOUT.sync = true
        @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to start..." if !to_be_watched.empty?
        while !to_be_watched.empty?
          instances =  @ec2.describe_instances()
          to_be_watched.each do |node_name|
            instance = find_ec2_node_instance(node_name, instances)
            if !instance.nil? && instance.instanceState.name.eql?("running")
              @logger.progress "\n"
              @logger.info "Node #{node_name} started (instance #{instance.instanceId}, host: #{instance.dnsName})"
              to_be_watched.delete(node_name)
              @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to start..." if !to_be_watched.empty?
            else
              @logger.progress "."
            end
          end
          sleep 5 if !to_be_watched.empty?
        end
      end

      # ensures that the Elb nodes of this cloud are running
      def ensure_elb_nodes
        all_balancers =  @elb.describe_load_balancers()
        to_be_started = Array.new
        @elb_nodes.keys.each do |node_name|
          node_instance = find_elb_node_instance(node_name, all_balancers)
          if node_instance.nil?
            @logger.info "Node #{node_name} not running. Starting..."
            to_be_started << node_name
          else
            @logger.info "Node #{node_name} already running (host: #{node_instance.DNSName})"
          end
        end
        to_be_started.each do |node_name|
          node = @nodes[node_name]
          # TODO: What to do about availability zones tied to this elb's instances, but not specified here? Validation error? Leave it to the user?
          elb = @elb.create_load_balancer(:load_balancer_name => node.load_balancer_name, :availability_zones => node.availability_zones, :listeners => node.listeners)
          node.hostname = elb.CreateLoadBalancerResult.DNSName
          @logger.info "Node #{node_name} started (host: #{node.hostname})"
          if !node.health_check.nil?
            @elb.configure_health_check({:health_check => node.health_check,
                                         :load_balancer_name => node.load_balancer_name})
          end
          if !node.ec2_nodes.nil?
            instance_ids = Array.new
            all_instances =  @ec2.describe_instances()
            node.ec2_nodes.each do |ec2_node_name|
              instance = find_ec2_node_instance(ec2_node_name, all_instances)
              if instance.nil?
                @logger.error "ERROR: Ec2 node '#{ec2_node_name}' is not running to map to Elb node '#{node.name}'"
              else
                instance_ids << instance.instanceId
              end
            end
            instance_ids.sort!
            begin
              response = @elb.register_instances_with_load_balancer(:load_balancer_name => node.load_balancer_name, :instances => instance_ids)
              if !response.RegisterInstancesWithLoadBalancerResult.nil? && !response.RegisterInstancesWithLoadBalancerResult.Instances.nil?
                registered_instances = Array.new
                response.RegisterInstancesWithLoadBalancerResult.Instances.member.each do |member|
                  registered_instances << member.InstanceId
                end
                registered_instances.sort!
                if instance_ids.eql?(registered_instances)
                  @logger.info "Registered Ec2 Nodes #{node.ec2_nodes.inspect} with Elb Node #{node_name}"
                else
                  @logger.error "ERROR: Could not register all Ec2 Nodes #{node.ec2_nodes.inspect} with Elb Node #{node_name}. The following instances are registered: #{registered_instances}"
                end
              else
                @logger.error "ERROR: Could not register Ec2 Nodes #{node.ec2_nodes.inspect} with Elb Node #{node_name}"
              end
            rescue AWS::Error => aws_error
              @logger.error "ERROR: Could not register Ec2 Nodes #{node.ec2_nodes.inspect} with Elb Node #{node_name}: #{aws_error.message}"
            end
          end
        end
      end

      # predicate indicating if the given Elastic IP address is allocated to this Cloud's AWS account
      def elastic_ip_allocated?(elastic_ip)
        begin
          ip = @ec2.describe_addresses(:public_ip => [elastic_ip])
          return true if !ip.nil?
        rescue AWS::Error => aws_error
          return false if aws_error.message.eql? "Address '#{elastic_ip}' not found."
        end
        return false
      end

      # returns the instance_id which the given Elastic IP is associated with, or nil if it is not associated
      def elastic_ip_association(elastic_ip)
        begin
          ip = @ec2.describe_addresses(:public_ip => [elastic_ip])
          return ip.addressesSet.item[0].instanceId if !ip.nil? && !ip.addressesSet.nil?
        rescue AWS::Error => aws_error
          return nil if aws_error.message.eql? "Address '#{elastic_ip}' not found."
        end
        return nil
      end

      # ensures that all configured Elastic IPs have been associated to the given nodes
      def ensure_elastic_ips
        all_instances = @ec2.describe_instances()
        @ec2_nodes.each_pair do |node_name, node|
          node_instance = find_ec2_node_instance(node_name, all_instances)
          if !node.elastic_ip.nil?
            if node_instance.nil?
              @logger.error "ERROR: Node #{node_name} doesn't appear to be running to associate with Elastic IP #{node.elastic_ip}"
            else
              if elastic_ip_allocated?(node.elastic_ip)
                associated_instance_id = elastic_ip_association(node.elastic_ip)
                if associated_instance_id.eql?(node_instance.instanceId)
                  @logger.info "Elastic IP Address #{node.elastic_ip} is already associated with Node #{node_name}"
                else
                  if associated_instance_id.nil?
                    @ec2.associate_address(:instance_id => node_instance.instanceId, :public_ip => node.elastic_ip)
                    @logger.info "Associated Elastic IP Address #{node.elastic_ip} with Node #{node_name}"
                  else
                    @logger.info "Elastic IP Address #{node.elastic_ip} is associated with the wrong instance (instance #{associated_instance_id}). Disassociating."
                    @ec2.disassociate_address(:public_ip => node.elastic_ip)
                    @ec2.associate_address(:instance_id => node_instance.instanceId, :public_ip => node.elastic_ip)
                    @logger.info "Associated Elastic IP Address #{node.elastic_ip} with Node #{node_name}"
                  end
                end
              else
                @logger.error "ERROR: Elastic IP Address #{node.elastic_ip} is not allocated to this AWS Account"
              end
            end
          end
        end
      end

      # predicate indicating if the given EBS volume is allocated to this Cloud's AWS account
      def ebs_volume_allocated?(volume_id)
        begin
          volume = @ec2.describe_volumes(:volume_id => [volume_id])
          return true if !volume.nil?
        rescue AWS::Error => aws_error
          return false if aws_error.message.eql? "The volume '#{volume_id}' does not exist."
        end
        return false
      end

      # returns the instance_id which the given EBS volume is associated with, or nil if it is not associated
      def ebs_volume_association(volume_id)
        begin
          volume = @ec2.describe_volumes(:volume_id => [volume_id])
          if !volume.nil? && !volume.volumeSet.nil? && !volume.volumeSet.item.nil? && !volume.volumeSet.item[0].attachmentSet.nil?
            return volume.volumeSet.item[0].attachmentSet.item[0].instanceId
          end
        rescue AWS::Error => aws_error
          return nil if aws_error.message.eql? "The volume '#{volume_id}' does not exist."
        end
        return nil
      end

      # ensures that all configured EBS volumes have been associated to the given nodes
      def ensure_ebs_volumes
        all_instances = @ec2.describe_instances()
        @ec2_nodes.each_pair do |node_name, node|
          node_instance = find_ec2_node_instance(node_name, all_instances)
          if !node.ebs_volume_id.nil? && !node.ebs_device.nil?
            if node_instance.nil?
              @logger.error "ERROR: Node #{node_name} doesn't appear to be running to attach EBS Volume #{node.ebs_volume_id}"
            else
              if ebs_volume_allocated?(node.ebs_volume_id)
                associated_instance_id = ebs_volume_association(node.ebs_volume_id)
                if associated_instance_id.eql?(node_instance.instanceId)
                  @logger.info "EBS Volume #{node.ebs_volume_id} is already attached to Node #{node_name}"
                else
                  begin
                    STDOUT.sync = true
                    if associated_instance_id.nil?
                      @logger.progress "Attaching EBS Volume #{node.ebs_volume_id} to Node #{node_name}..."
                      @ec2.attach_volume(:instance_id => node_instance.instanceId, :volume_id => node.ebs_volume_id, :device => node.ebs_device)
                      to_be_watched = [node.ebs_volume_id]
                      while !to_be_watched.empty?
                        volumes =  @ec2.describe_volumes(:volume_id => to_be_watched[0])
                        if !volumes.volumeSet.item[0].attachmentSet.nil? && volumes.volumeSet.item[0].attachmentSet.item[0].status.eql?("attached")
                          to_be_watched.clear
                        else
                          @logger.progress "."
                        end
                        sleep 5 if !to_be_watched.empty?
                      end
                      @logger.info "done."
                    else
                      @logger.progress "EBS Volume #{node.ebs_volume_id} is attached to the wrong instance (instance #{associated_instance_id}). Detaching..."
                      @ec2.detach_volume(:volume_id => node.ebs_volume_id)
                      to_be_watched = [node.ebs_volume_id]
                      while !to_be_watched.empty?
                        volumes =  @ec2.describe_volumes(:volume_id => to_be_watched[0])
                        if volumes.volumeSet.item[0].status.eql? "available"
                          to_be_watched.clear
                        else
                          @logger.progress "."
                        end
                        sleep 5 if !to_be_watched.empty?
                      end
                      @logger.info "done."
                      @logger.progress "Attaching EBS Volume #{node.ebs_volume_id} to Node #{node_name}..."
                      @ec2.attach_volume(:instance_id => node_instance.instanceId, :volume_id => node.ebs_volume_id, :device => node.ebs_device)
                      to_be_watched = [node.ebs_volume_id]
                      while !to_be_watched.empty?
                        volumes =  @ec2.describe_volumes(:volume_id => to_be_watched[0])
                        if !volumes.volumeSet.item[0].attachmentSet.nil? && volumes.volumeSet.item[0].attachmentSet.item[0].status.eql?("attached")
                          to_be_watched.clear
                        else
                          @logger.progress "."
                        end
                        sleep 5 if !to_be_watched.empty?
                      end
                      @logger.info "done."
                    end
                  rescue AWS::Error => aws_error
                    @logger.error "Error attaching EBS Volume #{node.ebs_volume_id} to Node #{node_name}: #{aws_error.inspect}"
                  end
                end
              else
                @logger.error "ERROR: EBS Volume #{node.ebs_volume_id} is not allocated to this AWS Account"
              end
            end
          end
        end
      end

      # ensures the project's Chef cookbooks and roles are deployed to the configured S3 Bucket
      def upload_chef_assets
        bucket = AWS::S3::Bucket.find(chef_bucket)
        if bucket.nil?
          @logger.info "Creating S3 Bucket '#{chef_bucket}'..."
          bucket = AWS::S3::Bucket.create(chef_bucket, :access => :private)
          @logger.info "Created S3 Bucket '#{chef_bucket}'" if !bucket.nil?
        end

        @logger.info "Packaging Chef assets..."
        chef_tgz = Maestro.chef_archive
        @logger.info "Uploading Chef assets to S3 bucket '#{chef_bucket}'..."
        AWS::S3::S3Object.store(MAESTRO_CHEF_ARCHIVE, File.open(chef_tgz, "r"), chef_bucket, :access => :private)
        @logger.info "Chef assets uploaded to S3 Bucket '#{chef_bucket}' as key '#{MAESTRO_CHEF_ARCHIVE}'"

        @logger.info "Uploading Node JSON files to S3 Bucket '#{chef_bucket}'..." if !@configurable_nodes.empty?
        @configurable_nodes.each_pair do |node_name, node|
          AWS::S3::S3Object.store(node.json_filename, node.json, chef_bucket, :access => :private)
          @logger.info "Node #{node.name} JSON file uploaded to S3 Bucket '#{chef_bucket}' as key '#{node.json_filename}'"
        end
      end

      # Returns the URL to the Chef assets tar ball
      def chef_assets_url
        AWS::S3::S3Object.url_for(MAESTRO_CHEF_ARCHIVE, chef_bucket, :expires_in => 600, :use_ssl => true)
      end

      # Returns the URL for the given node's Chef JSON file
      def node_json_url(node)
        AWS::S3::S3Object.url_for(node.json_filename, chef_bucket, :expires_in => 600, :use_ssl => true)
      end

      # Collects the current hostnames of all running Configurable Nodes
      def get_configurable_node_hostnames
        all_instances =  @ec2.describe_instances()
        @ec2_nodes.each_pair do |node_name, node|
          node_instance = find_ec2_node_instance(node_name, all_instances)
          if node_instance.nil?
            @logger.error "ERROR: node #{node_name} not running!"
          else
            node.hostname = node_instance.dnsName
          end
        end
      end

      # Ensures that the Nodes of this Cloud are terminated
      def ensure_nodes_terminated
        ensure_elb_nodes_terminated
        ensure_ec2_nodes_terminated
        ensure_rds_nodes_terminated
      end

      # Ensures that the Ec2 Nodes of this Cloud are terminated
      def ensure_ec2_nodes_terminated
        all_instances =  @ec2.describe_instances()
        to_be_terminated = Array.new
        to_be_watched = Array.new
        @ec2_nodes.each_pair do |node_name, node|
          node_instance = find_ec2_node_instance(node_name, all_instances)
          if node_instance.nil?
            @logger.info "Node #{node_name} already terminated"
          elsif node_instance.instanceState.name.eql?("shutting-down")
            @logger.info "Node #{node_name} terminating..."
            to_be_watched << node_name
          elsif node_instance.instanceState.name.eql?("pending") || node_instance.instanceState.name.eql?("running")
            @logger.info "Node #{node_name} running. Terminating..."
            to_be_terminated << node_instance.instanceId
            to_be_watched << node_name
          end
        end
        if !to_be_terminated.empty?
          @ec2.terminate_instances(:instance_id => to_be_terminated)
          @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to terminate..." if !to_be_watched.empty?
        end
        STDOUT.sync = true
        while !to_be_watched.empty?
          instances =  @ec2.describe_instances()
          to_be_watched.each do |node_name|
            instance = find_ec2_node_instance(node_name, instances)
            if instance.nil?
              @logger.progress "\n"
              @logger.info "Node #{node_name} terminated"
              to_be_watched.delete(node_name)
              @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to terminate..." if !to_be_watched.empty?
            else
              @logger.progress "."
            end
          end
          sleep 5 if !to_be_watched.empty?
        end
      end

      # Ensures that the Elb Nodes of this Cloud are terminated
      def ensure_elb_nodes_terminated
        balancers = @elb.describe_load_balancers
        to_be_deleted = Hash.new
        @elb_nodes.each_pair do |node_name, node|
          instance = find_elb_node_instance(node_name, balancers)
          if !instance.nil?
            @logger.info "Node #{node_name} terminating..."
            to_be_deleted[node_name] = node.load_balancer_name
          else
            @logger.info "Node #{node_name} already terminated"
          end
        end
        if !to_be_deleted.empty?
          to_be_deleted.each_pair do |node_name, load_balancer_name|
            @elb.delete_load_balancer(:load_balancer_name => load_balancer_name)
            @logger.info "Node #{node_name} terminated"
          end
        end
      end

      # Ensures that the Rds Nodes of this Cloud are terminated
      def ensure_rds_nodes_terminated
        all_instances =  @rds.describe_db_instances
        wait_for = Hash.new
        to_be_terminated = Array.new
        to_be_watched = Array.new
        @rds_nodes.each_pair do |node_name, node|
          node_instance = find_rds_node_instance(node.db_instance_identifier, all_instances)
          if node_instance.nil?
            @logger.info "Node #{node_name} already terminated"
          elsif node_instance.DBInstanceStatus.eql?("deleting")
            @logger.info "Node #{node_name} terminating..."
            to_be_watched << node_name
          elsif (node_instance.DBInstanceStatus.eql?("creating") || 
                 node_instance.DBInstanceStatus.eql?("rebooting") ||
                 node_instance.DBInstanceStatus.eql?("modifying") ||
                 node_instance.DBInstanceStatus.eql?("resetting-mastercredentials") ||
                 node_instance.DBInstanceStatus.eql?("backing-up"))
            @logger.info "Waiting for Node #{node_name} to finish #{node_instance.DBInstanceStatus} before terminating..."
            wait_for[node_name] = node_instance.DBInstanceStatus
          elsif (node_instance.DBInstanceStatus.eql?("available") ||
                 node_instance.DBInstanceStatus.eql?("failed") ||
                 node_instance.DBInstanceStatus.eql?("storage-full"))
            @logger.info "Node #{node_name} running. Terminating..."
            to_be_terminated << node_name
          end
        end

        @logger.progress "Waiting for Nodes #{wait_for.keys.inspect}..." if !wait_for.empty?
        while !wait_for.empty?
          instances =  @rds.describe_db_instances
          wait_for.each_pair do |node_name, status|
            node = @nodes[node_name]
            node_instance = find_rds_node_instance(node.db_instance_identifier, instances)
            if (node_instance.DBInstanceStatus.eql?("available") ||
                node_instance.DBInstanceStatus.eql?("failed") ||
                node_instance.DBInstanceStatus.eql?("storage-full"))
              @logger.progress "\n"
              @logger.info "Node #{node_name} done #{status}. Terminating..."
              wait_for.delete(node_name)
              to_be_terminated << node_name
              @logger.progress "Waiting for Nodes #{wait_for.keys.inspect}..." if !wait_for.empty?
            else
              @logger.progress "."
            end
          end
          sleep 5 if !wait_for.empty?
        end

        to_be_terminated.each do |node_name|
          node = @nodes[node_name]
          now = DateTime.now
          final_snapshot = node.db_instance_identifier + "-" + now.to_s.gsub(/:/, '')
          @logger.info "Terminating Node #{node_name} with final snapshot id '#{final_snapshot}' ..."
          result = @rds.delete_db_instance(:db_instance_identifier => node.db_instance_identifier, :final_db_snapshot_identifier => final_snapshot)
          to_be_watched << node_name
        end
        STDOUT.sync = true
        @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to terminate. This may take several minutes..." if !to_be_watched.empty?
        while !to_be_watched.empty?
          instances =  @rds.describe_db_instances
          to_be_watched.each do |node_name|
            node = @nodes[node_name]
            instance = find_rds_node_instance(node.db_instance_identifier, instances)
            if instance.nil?
              @logger.progress "\n"
              @logger.info "Node #{node_name} terminated"
              to_be_watched.delete(node_name)
              @logger.progress "Waiting for Nodes #{to_be_watched.inspect} to terminate. This may take several minutes..." if !to_be_watched.empty?
            else
              @logger.progress "."
            end
          end
          sleep 5 if !to_be_watched.empty?
        end
      end


      private

      # validates this Aws instance
      def validate_internal
        super
        invalidate "Missing aws_account_id" if aws_account_id.nil?
        invalidate "Missing aws_access_key" if aws_access_key.nil?
        invalidate "Missing aws_secret_access_key" if aws_secret_access_key.nil?
        invalidate "Missing chef_bucket" if chef_bucket.nil?
      end

      # Ensures that the given EC2 security group exists. Creates it if it does not exist.
      def ensure_ec2_security_group(group_name)
        security_groups =  @ec2.describe_security_groups()
        names = Array.new
        if !security_groups.nil? && !security_groups.securityGroupInfo.nil? && !security_groups.securityGroupInfo.item.nil?
          security_groups.securityGroupInfo.item.each {|group| names << group.groupName}
        end
        unless names.include?(group_name)
          @ec2.create_security_group(:group_name => group_name, :group_description => "#{group_name} group")
        end
      end

      # Ensures that the given EC2 security group cidr range configuration exists
      # * group_name - the security group name to configure
      # * from_port - the port to allow from
      # * to_port - the port to allow to
      # * protocol - the protocol to allow (one of 'tcp', 'udp', or 'icmp')
      # * cidr_ip - optional cidr IP address configuration
      def ensure_ec2_security_group_cidr_configuration(group_name, from_port, to_port, protocol, cidr_ip='0.0.0.0/0')
        security_group =  @ec2.describe_security_groups(:group_name => [group_name])
        found_rule = false
        if !security_group.nil?
          ip_permissions = security_group.securityGroupInfo.item[0].ipPermissions
          if !ip_permissions.nil?
            ip_permissions.item.each do |permission|
              if !permission.ipProtocol.nil? && permission.ipProtocol.eql?(protocol) && permission.fromPort.eql?(from_port.to_s) && permission.toPort.eql?(to_port.to_s) && permission.ipRanges.item[0].cidrIp.eql?(cidr_ip)
                found_rule = true
              end
            end
          end
        end
        if !found_rule
          @ec2.authorize_security_group_ingress(:group_name => group_name,
                                                :ip_protocol => protocol,
                                                :from_port => from_port,
                                                :to_port => to_port,
                                                :cidr_ip => cidr_ip)
        end
      end

      # Ensures that the given EC2 security group name configuration exists
      # * group_name - the security group granting access to
      # * their_group_name - the security group granting access from
      # * their_account_id - the account id of their_group_name
      def ensure_ec2_security_group_name_configuration(group_name, their_group_name, their_account_id)
        security_group =  @ec2.describe_security_groups(:group_name => [group_name])
        found_rule = false
        if !security_group.nil?
          ip_permissions = security_group.securityGroupInfo.item[0].ipPermissions
          if !ip_permissions.nil?
            ip_permissions.item.each do |permission|
              if !permission.groups.nil? && permission.groups.item[0].groupName.eql?(their_group_name) && permission.groups.item[0].userId.gsub(/-/,'').eql?(their_account_id.gsub(/-/,''))
                found_rule = true
              end
            end
          end
        end
        if !found_rule
          @ec2.authorize_security_group_ingress(:group_name => group_name,
                                                :source_security_group_name => their_group_name,
                                                :source_security_group_owner_id => their_account_id)
        end
      end
    end
  end
end


module Maestro
  module Node
    module Aws
      # Amazon EC2 Node
      class Ec2 < Configurable

        dsl_property :ami, :ssh_user, :instance_type, :availability_zone, :elastic_ip, :ebs_volume_id, :ebs_device
        attr_accessor :security_groups
        attr_accessor :node_security_group
        attr_accessor :role_security_groups

        # Creates a new Ec2 Node
        def initialize(name, cloud, &block)
          super(name, cloud, &block)
          @security_groups = Array.new
          @role_security_groups = Array.new
          @node_security_group = "#{node_prefix}#{@name}"
          @security_groups << @node_security_group
          if !@roles.nil? && !@roles.empty?
            @roles.each do |role_name|
              role_security_group = "#{role_prefix}#{role_name}"
              @role_security_groups << role_security_group
              @security_groups << role_security_group
            end
          end
        end

        # sets the default security group for the cloud on this Ec2 Node
        def set_default_security_group(security_group)
          @security_groups << security_group if !@security_groups.include?(security_group)
          @role_security_groups << security_group if !@role_security_groups.include?(security_group)
        end


        private

        # returns the security group name prefix to be used for all node security groups pertaining to this Cloud
        def node_prefix()
          "#{@cloud.name}.#{Maestro::Cloud::Aws::MAESTRO_NODE_PREFIX}"
        end

        # returns the security group name prefix to be used for all role security groups pertaining to this Cloud
        def role_prefix()
          "#{@cloud.name}.#{Maestro::Cloud::Aws::MAESTRO_ROLE_PREFIX}"
        end

        # validates this Ec2 Node
        def validate_internal
          super
          invalidate "'#{@name}' node missing ami" if ami.nil?
          invalidate "'#{@name}' node missing instance_type" if instance_type.nil?
          invalidate "'#{@name}' node missing availability_zone" if availability_zone.nil?
          if (!ebs_volume_id.nil? && ebs_device.nil?)
            invalidate "'#{@name}' node missing ebs_device (you must specify both ebs_volume_id and ebs_device)"
          end
          if (ebs_volume_id.nil? && !ebs_device.nil?)
            invalidate "'#{@name}' node missing ebs_volume_id (you must specify both ebs_volume_id and ebs_device)"
          end
        end
      end
    end
  end
end


module Maestro
  module Node
    module Aws
      # Amazon ELB Node
      class Elb < Base

        # The load balancer name of this node
        attr_reader :load_balancer_name
        dsl_property :listeners, :ec2_nodes, :availability_zones, :health_check

        def initialize(name, cloud, &block)
          super(name, cloud, &block)
          @load_balancer_name = set_load_balancer_name
        end


        private

        # Sets the load balancer name to use for this Elb Node.
        # ELB names may only have letters, digits, and dashes, and may not be longer
        # than 32 characters. This method will remove any invalid characters from the calculated name.
        # If the calculated elb node name is > 32 characters, this method will truncate the name
        # to the last 32 characters of the calculated name. This name may NOT be unique across all
        # of your clouds.
        def set_load_balancer_name
          str = "#{@cloud.name.to_s.gsub(/[^[:alnum:]-]/, '')}-#{@name.to_s.gsub(/[^[:alnum:]-]/, '')}"
          str = str[str.size-32,32] if str.size > 32
          return str
        end

        # validates this Elb
        def validate_internal
          super
          invalidate "'#{@name}' node's name must be less than 32 characters" if @name.length > 32
          invalidate "'#{@name}' node's name must start with a letter" unless @name =~ /^[A-Za-z]/
          invalidate "'#{@name}' node's name may only contain alphanumerics and hyphens" unless @name =~ /^[a-zA-Z][[:alnum:]-]{1,62}/
          invalidate "'#{@name}' node's name must not end with a hypen" if @name =~ /-$/
          invalidate "'#{@name}' node's name must not contain two consecutive hyphens" if @name =~ /--/
          invalidate "'#{@name}' node missing listeners" if listeners.nil?
          invalidate "'#{@name}' node's listeners must be an Array of Hashes" if !listeners.is_a?(Array)
          if !listeners.nil? && listeners.is_a?(Array)
            listeners.each do |listener|
              if !listener.is_a?(Hash)
                invalidate "'#{@name}' node's listeners must be an Array of Hashes"
              else
                invalidate "'#{@name}' node's listeners Hash missing :load_balancer_port key" if !listener.has_key?(:load_balancer_port)
                invalidate "'#{@name}' node's listeners Hash missing :instance_port key" if !listener.has_key?(:instance_port)
                invalidate "'#{@name}' node's listeners Hash missing :protocol key" if !listener.has_key?(:protocol)
              end
            end
          end
          invalidate "'#{@name}' node missing ec2_nodes collection" if ec2_nodes.nil?
          invalidate "'#{@name}' node ec2_nodes collection is not an Array (found #{ec2_nodes.class})" if !ec2_nodes.is_a?(Array)
          invalidate "'#{@name}' node missing availability_zones collection" if availability_zones.nil?
          invalidate "'#{@name}' node availability_zones collection is not an Array (found #{availability_zones.class})" if !availability_zones.is_a?(Array)
          if !health_check.is_a?(Hash)
            invalidate "'#{@name}' node's health_check must be a Hash"
          else
            invalidate "'#{@name}' node's health_check Hash missing :target key" if !health_check.has_key?(:target)
            invalidate "'#{@name}' node's health_check Hash missing :timeout key" if !health_check.has_key?(:timeout)
            invalidate "'#{@name}' node's health_check Hash missing :interval key" if !health_check.has_key?(:interval)
            invalidate "'#{@name}' node's health_check Hash missing :unhealthy_threshold key" if !health_check.has_key?(:unhealthy_threshold)
            invalidate "'#{@name}' node's health_check Hash missing :healthy_threshold key" if !health_check.has_key?(:healthy_threshold)
          end
        end
      end
    end
  end
end


module Maestro
  module Node
    module Aws
      # Amazon RDS Node
      class Rds < Base

        # the db_instance_identifier of this node
        attr_reader :db_instance_identifier
        
        # the db parameter group name of this node
        attr_reader :db_parameter_group_name

        # the db security group name of this node
        attr_reader :db_security_group_name

        dsl_property :availability_zone, :engine, :db_instance_class, :master_username, :master_user_password,
                     :port, :allocated_storage, :backup_retention_period, :preferred_maintenance_window,
                     :preferred_backup_window, :db_parameters

        def initialize(name, cloud, &block)
          super(name, cloud, &block)
          @db_instance_identifier = set_db_instance_identifier
          @db_parameter_group_name = set_db_parameter_group_name if !db_parameters.nil? && !db_parameters.empty?
          @db_security_group_name = set_db_security_group_name
        end


        private

        # Returns a name to tag an RDS instance as being an Rds Node.
        # RDS names may only have letters, digits, and dashes, and may not be longer
        # than 63 characters. This method will remove any invalid characters from the calculated name.
        # If the calculated elb node name is > 63 characters, this method will truncate the name
        # to the last 63 characters of the calculated name. This name may NOT be unique across all
        # of your clouds.
        def set_db_instance_identifier
          str = "#{@cloud.name.to_s.gsub(/[^[:alnum:]-]/, '')}-#{@name.to_s.gsub(/[^[:alnum:]-]/, '')}"
          str = str[str.size-63,63] if str.size > 63
          return str
        end

        # Returns the name of this RDS node's db parameter group.
        # Parameter group names may only have letters, digits, and dashes, and may not be longer
        # than 255 characters. This method will remove any invalid characters from the calculated name.
        # If the calculated elb node name is > 255 characters, this method will truncate the name
        # to the last 255 characters of the calculated name. This name may NOT be unique across all
        # of your clouds.
        def set_db_parameter_group_name
          str = "#{@cloud.name.to_s.gsub(/[^[:alnum:]-]/, '')}-#{@name.to_s.gsub(/[^[:alnum:]-]/, '')}-dbparams"
          str = str[str.size-255,255] if str.size > 255
          return str
        end

        # Returns the name of this RDS node's db security group.
        # DB Security group names may only have letters, digits, and dashes, and may not be longer
        # than 255 characters. This method will remove any invalid characters from the calculated name.
        # If the calculated elb node name is > 255 characters, this method will truncate the name
        # to the last 255 characters of the calculated name. This name may NOT be unique across all
        # of your clouds.
        def set_db_security_group_name
          str = "#{@cloud.name.to_s.gsub(/[^[:alnum:]-]/, '')}-#{@name.to_s.gsub(/[^[:alnum:]-]/, '')}-security-group"
          str = str[str.size-255,255] if str.size > 255
          return str
        end

        # validates this Rds
        def validate_internal
          super
          invalidate "'#{@name}' node's name must be less than 64 characters" if @name.length > 63
          invalidate "'#{@name}' node's name must start with a letter" unless @name =~ /^[A-Za-z]/
          invalidate "'#{@name}' node's name may only contain alphanumerics and hyphens" unless @name =~ /^[a-zA-Z][[:alnum:]-]{1,62}/
          invalidate "'#{@name}' node's name must not end with a hypen" if @name =~ /-$/
          invalidate "'#{@name}' node's name must not contain two consecutive hyphens" if @name =~ /--/

          invalidate "'#{@name}' node missing availability_zone" if availability_zone.nil?

          invalidate "'#{@name}' node missing engine" if engine.nil?
          engines = ["MySQL5.1"]
          invalidate "'#{@name}' node engine is invalid" if !engines.include?(engine)

          invalidate "'#{@name}' node missing db_instance_class" if db_instance_class.nil?
          db_instance_classes = ["db.m1.small", "db.m1.large", "db.m1.xlarge", "db.m2.2xlarge", "db.m2.4xlarge"]
          invalidate "'#{@name}' node db_instance_class is invalid" if !db_instance_classes.include?(db_instance_class)

          if !master_username.nil?
            invalidate "'#{@name}' node's master_username must be less than 16 characters" if master_username.length > 15
            invalidate "'#{@name}' node's master_username must start with a letter" unless master_username =~ /^[A-Za-z]/
            invalidate "'#{@name}' node's master_username may only contain alphanumerics" unless master_username =~ /^[a-zA-Z][[:alnum:]]{0,14}$/
          else
            invalidate "'#{@name}' node missing master_username"
          end

          if !master_user_password.nil?
            invalidate "'#{@name}' node's master_user_password must be between 4 and 16 characters in length" if master_user_password.length < 4 || master_user_password.length > 16
            invalidate "'#{@name}' node's master_user_password may only contain alphanumerics" unless master_user_password =~ /^[[:alnum:]]{4,16}$/
          else
            invalidate "'#{@name}' node missing master_user_password"
          end

          if !port.nil?
            if port.respond_to? :to_i
              invalidate "node's port must be between 1150 and 65535" if port.to_i < 1150 || port.to_i > 65535
            else
              invalidate "'#{@name}' node's port must be a number"
            end
          else
            invalidate "'#{@name}' node missing port"
          end

          if !allocated_storage.nil?
            if allocated_storage.respond_to? :to_i
              invalidate "node's allocated_storage must be between 5 and 1024" if allocated_storage.to_i < 5 || allocated_storage.to_i > 1024
            else
              invalidate "'#{@name}' node's allocated_storage must be a number"
            end
          else
            invalidate "'#{@name}' node missing allocated_storage"
          end

          if !preferred_maintenance_window.nil?
            invalidate "'#{@name}' node's preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'" unless preferred_maintenance_window =~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun):(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]-(Mon|Tue|Wed|Thu|Fri|Sat|Sun):(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/
          end

          if !backup_retention_period.nil?
            if backup_retention_period.respond_to? :to_i
              invalidate "'#{@name}' node's backup_retention_period must be between 0 and 8" unless backup_retention_period.to_i >= 0 && backup_retention_period.to_i <= 8
            else
              invalidate "'#{@name}' node's backup_retention_period must be a number"
            end
          end

          if !preferred_backup_window.nil?
            invalidate "'#{@name}' node's preferred_backup_window must be in UTC format 'hh24:mi-hh24:mi'" unless preferred_backup_window =~ /^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]-(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/
          end
        end
      end
    end
  end
end
