require "helper"
require "base_aws"


# Integration tests for Maestro::Cloud::Aws
class TestAwsCloud < Test::Unit::TestCase

  include BaseAws

  context "Maestro::Cloud::Aws" do

    #######################
    # Setup
    #######################
    setup do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(File.expand_path(__FILE__)), 'fixtures')
      Maestro.create_log_dirs
      credentials = @credentials
      @cloud = aws_cloud :maestro_aws_itest do
        keypair_name credentials[:keypair_name]
        keypair_file credentials[:keypair_file]
        aws_account_id credentials[:aws_account_id]
        aws_access_key credentials[:aws_access_key]
        aws_secret_access_key credentials[:aws_secret_access_key]
        chef_bucket credentials[:chef_bucket]

        roles do
          role "web" do
            public_ports [80, 443]
          end
        end

        nodes do
          elb_node "lb-1" do
            availability_zones ["us-east-1b"]
            listeners [{:load_balancer_port => 80, :instance_port => 80, :protocol => "http"}]
            ec2_nodes ["node-1", "node-2"]
            health_check(:target => "TCP:80", :timeout => 15, :interval => 60, :unhealthy_threshold => 5, :healthy_threshold => 3)
          end

          ec2_node "node-1" do
            roles ["web"]
            ami "ami-bb709dd2"
            ssh_user "ubuntu"
            instance_type "m1.small"
            availability_zone "us-east-1b"
          end

          ec2_node "node-2" do
            roles ["web"]
            ami "ami-bb709dd2"
            ssh_user "ubuntu"
            instance_type "m1.small"
            availability_zone "us-east-1b"
          end

          rds_node "db-1" do
            engine "MySQL5.1"
            db_instance_class "db.m1.small"
            master_username "root"
            master_user_password "password"
            port 3306
            allocated_storage 5
            availability_zone "us-east-1b"
            preferred_maintenance_window "Sun:03:00-Sun:07:00"
            preferred_backup_window "03:00-05:00"
            backup_retention_period 7
            db_parameters [{:name => "character_set_server", :value => "utf8"},
                           {:name => "collation_server", :value => "utf8_bin"},
                           {:name => "long_query_time", :value => "5"}]
          end
        end
      end
    end


    #######################
    # Teardown
    #######################

    teardown do
      # terminate ec2 instances
      instances = @ec2.describe_instances
      to_be_terminated = Array.new
      to_be_watched = Array.new
      @cloud.ec2_nodes.each_pair do |node_name, node|
        instance = @cloud.find_ec2_node_instance(node_name, instances)
        if !instance.nil?
          to_be_terminated << instance.instanceId
          to_be_watched << node_name
        end
      end
      if !to_be_terminated.empty?
        puts "Terminating AWS integration test EC2 instances"
        @ec2.terminate_instances(:instance_id => to_be_terminated)
      end
      STDOUT.sync = true
      print "Waiting for Nodes #{to_be_watched.inspect} to terminate..." if !to_be_watched.empty?
      while !to_be_watched.empty?
        instances =  @ec2.describe_instances()
        to_be_watched.each do |node_name|
          instance = @cloud.find_ec2_node_instance(node_name, instances)
          if instance.nil?
            puts ""
            puts "Node #{node_name} terminated"
            to_be_watched.delete(node_name)
            print "Waiting for Nodes #{to_be_watched.inspect} to terminate..." if !to_be_watched.empty?
          else
            print "."
          end
        end
        sleep 5 if !to_be_watched.empty?
      end

      # delete ELBs
      balancers = @elb.describe_load_balancers()
      to_be_deleted = Array.new
      @cloud.elb_nodes.each_pair do |node_name, node|
        instance = @cloud.find_elb_node_instance(node_name, balancers)
        if !instance.nil?
          to_be_deleted << node
        end
      end
      if !to_be_deleted.empty?
        puts "Deleting AWS integration test ELB instances"
        to_be_deleted.each do |node|
          puts "Deleting AWS integration test ELB: #{node.name}"
          @elb.delete_load_balancer(:load_balancer_name => node.load_balancer_name)
        end
      end

      # delete ec2 security groups
      @cloud.ec2_security_groups.each do |group_name|
        @ec2.delete_security_group(:group_name => group_name)
      end

      # delete RDS instances
      all_instances =  @rds.describe_db_instances
      wait_for = Hash.new
      to_be_terminated = Array.new
      to_be_watched = Array.new
      @cloud.rds_nodes.each_pair do |node_name, node|
        node_instance = @cloud.find_rds_node_instance(node.db_instance_identifier, all_instances)
        if !node_instance.nil?
          if node_instance.DBInstanceStatus.eql?("deleting")
            to_be_watched << node_name
          elsif (node_instance.DBInstanceStatus.eql?("creating") || 
                 node_instance.DBInstanceStatus.eql?("rebooting") ||
                 node_instance.DBInstanceStatus.eql?("modifying") ||
                 node_instance.DBInstanceStatus.eql?("resetting-mastercredentials") ||
                 node_instance.DBInstanceStatus.eql?("backing-up"))
            wait_for[node_name] = node_instance.DBInstanceStatus
          elsif (node_instance.DBInstanceStatus.eql?("available") ||
                 node_instance.DBInstanceStatus.eql?("failed") ||
                 node_instance.DBInstanceStatus.eql?("storage-full"))
            to_be_terminated << node_name
          end
        end
      end

      print "Waiting for AWS integration test RDS Nodes #{wait_for.inspect} to finish work before deleting. This may take several minutes..." if !wait_for.empty?
      while !wait_for.empty?
        instances =  @rds.describe_db_instances
        wait_for.each_pair do |node_name, status|
          node = @cloud.rds_nodes[node_name]
          node_instance = @cloud.find_rds_node_instance(node.db_instance_identifier, instances)
          if (node_instance.DBInstanceStatus.eql?("available") ||
              node_instance.DBInstanceStatus.eql?("failed") ||
              node_instance.DBInstanceStatus.eql?("storage-full"))
            puts ""
            wait_for.delete(node_name)
            to_be_terminated << node_name
            print "Waiting for AWS integration test RDS Nodes #{wait_for.inspect} to finish work before deleting. This may take several minutes..." if !wait_for.empty?
          else
            print "."
          end
        end
        sleep 5 if !wait_for.empty?
      end

      puts "Deleting AWS integration test RDS instances" if !to_be_terminated.empty?
      to_be_terminated.each do |node_name|
        node = @cloud.rds_nodes[node_name]
        now = DateTime.now
        final_snapshot = node.db_instance_identifier + "-" + now.to_s
        puts "Deleting RDS instance #{node_name}..."
        @rds.delete_db_instance(:db_instance_identifier => node.db_instance_identifier, :skip_final_snapshot => true)
        to_be_watched << node_name
      end
      STDOUT.sync = true
      print "Waiting for AWS integration test Nodes #{to_be_watched.inspect} to delete. This may take several minutes..." if !to_be_watched.empty?
      while !to_be_watched.empty?
        instances =  @rds.describe_db_instances
        to_be_watched.each do |node_name|
          node = @cloud.rds_nodes[node_name]
          instance = @cloud.find_rds_node_instance(node.db_instance_identifier, instances)
          if instance.nil?
            puts ""
            puts "Node #{node_name} deleted"
            to_be_watched.delete(node_name)
            print "Waiting for Nodes #{to_be_watched.inspect} to delete. This may take several minutes..." if !to_be_watched.empty?
          else
            print "."
          end
        end
        sleep 5 if !to_be_watched.empty?
      end

      # delete DB parameter groups
      @cloud.rds_nodes.each_pair do |node_name, node|
        if !node.db_parameters.nil?
          begin
            @rds.delete_db_parameter_group(:db_parameter_group_name => node.db_parameter_group_name)
            puts "Deleted AWS integration test DB parameter group: #{node.db_parameter_group_name}"
          rescue AWS::Error => aws_error
            if !aws_error.message.eql? "DBParameterGroup #{node.db_parameter_group_name} not found."
              # it didn't exist
            end
          end
        end
      end

      # delete DB security groups
      @cloud.rds_nodes.each_pair do |node_name, node|
        begin
          @rds.delete_db_security_group(:db_security_group_name => node.db_security_group_name)
          puts "Deleted AWS integration test DB security group: #{node.db_security_group_name}"
        rescue AWS::Error => aws_error
          if !aws_error.message.eql? "DBSecurityGroup #{node.db_security_group_name} not found."
            # it didn't exist
          end
        end
      end
      
      # delete DB snapshots
      @cloud.rds_nodes.each_pair do |node_name, node|
        begin
          snapshots = @rds.describe_db_snapshots(:db_instance_identifier => node.db_instance_identifier)
          if !snapshots.DescribeDBSnapshotsResult.DBSnapshots.nil?
            snapshots.DescribeDBSnapshotsResult.DBSnapshots.DBSnapshot.each do |snapshot|
              if snapshot.respond_to?(:DBSnapshotIdentifier)
                @rds.delete_db_snapshot(:db_snapshot_identifier => snapshot.DBSnapshotIdentifier)
                puts "Deleted AWS integration test DB snapshot: #{snapshot.DBSnapshotIdentifier}"
              end
            end
          end
        rescue AWS::Error => aws_error
          puts aws_error
        end
      end

      FileUtils.rm_rf([Maestro.maestro_log_directory], :secure => true) if File.exists?(Maestro.maestro_log_directory)
      ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
    end


    #######################
    # Tests
    #######################

    should "be able to connect to AWS" do
      assert_nothing_raised do
        @cloud.connect!
      end
    end

    should "report status" do
      assert_nothing_raised do
        @cloud.connect!
        # not running code path
        @cloud.status
      end
    end

    should "not have any nodes running" do
      instances = @ec2.describe_instances
      @cloud.ec2_nodes.each_pair do |node_name, node|
        assert @cloud.find_ec2_node_instance(node.name, instances).nil?
      end
      balancers = @elb.describe_load_balancers
      @cloud.elb_nodes.each_pair do |node_name, node|
        assert @cloud.find_elb_node_instance(node.name, balancers).nil?
      end
      db_instances = @rds.describe_db_instances
      @cloud.rds_nodes.each_pair do |node_name, node|
        assert @cloud.find_rds_node_instance(node.name, balancers).nil?
      end
    end

    should "not have any rds db parameter groups" do
      @cloud.db_parameter_groups.each do |group_name|
        begin
          group = @rds.describe_db_parameter_groups(:db_parameter_group_name => group_name)
          assert false
        rescue AWS::Error => aws_error
          assert aws_error.message.eql? "DBParameterGroup #{group_name} not found."
        end
      end
    end

    should "ensure rds db parameter groups" do
      assert_nothing_raised do
        @cloud.connect!
        # doesn't exist code path
        @cloud.ensure_rds_db_parameter_groups
        assert_rds_db_parameter_groups
        # already exists code path
        @cloud.ensure_rds_db_parameter_groups
        assert_rds_db_parameter_groups
      end
    end

    should "not have any rds db security groups" do
      @cloud.db_security_groups.each do |group_name|
        begin
          group = @rds.describe_db_security_groups(:db_security_group_name => group_name)
          assert false
        rescue AWS::Error => aws_error
          assert aws_error.message.eql? "DBSecurityGroup #{group_name} not found."
        end
      end
    end

    should "ensure rds db security groups" do
      assert_nothing_raised do
        @cloud.connect!
        # doesn't exist code path
        @cloud.ensure_rds_db_security_groups
        assert_rds_db_security_groups
        # already exists code path
        @cloud.ensure_rds_db_security_groups
        assert_rds_db_security_groups
      end
    end

    should "not have any ec2 security groups" do
      cloud_security_groups = @cloud.ec2_security_groups
      cloud_security_groups.each do |group_name|
        security_group =  @ec2.describe_security_groups(:group_name => [group_name])
        assert security_group.nil?
      end
    end

    should "ensure ec2 security groups" do
      assert_nothing_raised do
        @cloud.connect!
        # doesn't exist code path
        @cloud.ensure_ec2_security_groups
        assert_ec2_security_groups_created
        assert_role_ec2_security_groups
        # already exists code path
        @cloud.ensure_ec2_security_groups
        assert_ec2_security_groups_created
        assert_role_ec2_security_groups
      end
    end

    should "ensure nodes running" do
      assert_nothing_raised do
        @cloud.connect!
        @cloud.ensure_rds_security_groups
        @cloud.ensure_rds_db_parameter_groups
        @cloud.ensure_ec2_security_groups
        @cloud.ensure_rds_db_security_groups
        # not running code path
        @cloud.ensure_nodes_running
        assert_rds_nodes_running
        assert_ec2_nodes_running
        assert_elb_nodes_running
        # already running code path
        @cloud.ensure_nodes_running
        assert_rds_nodes_running
        assert_ec2_nodes_running
        assert_elb_nodes_running
      end
    end

    should "not find a bogus elastic ip allocated" do
      assert_nothing_raised do
        @cloud.connect!
        assert !@cloud.elastic_ip_allocated?("127.0.0.1")
      end
    end

    should "find an allocated elastic ip" do
      assert_nothing_raised do
        @cloud.connect!
        elastic_ip = @ec2.allocate_address
        assert @cloud.elastic_ip_allocated?(elastic_ip.publicIp)
      end
    end

    should "ensure elastic ips" do
      assert_nothing_raised do
        @cloud.nodes.delete("lb-1")
        @cloud.elb_nodes.delete("lb-1")
        @cloud.nodes.delete("db-1")
        @cloud.rds_nodes.delete("db-1")
        # case 1: associate an Elastic IP to node_1
        elastic_ip = @ec2.allocate_address
        @cloud.nodes["node-1"].elastic_ip(elastic_ip.publicIp)
        @cloud.connect!
        @cloud.ensure_ec2_security_groups
        @cloud.ensure_nodes_running
        @cloud.ensure_elastic_ips
        instances = @ec2.describe_instances
        instance = @cloud.find_ec2_node_instance("node-1", instances)
        instance_id = @cloud.elastic_ip_association(elastic_ip.publicIp)
        assert instance_id.eql?(instance.instanceId)
        # case 2: disassociate Elastic IP from node_1 and associate with node_2
        @cloud.nodes["node-1"].elastic_ip(nil)
        @cloud.nodes["node-2"].elastic_ip(elastic_ip.publicIp)
        @cloud.ensure_elastic_ips
        instances = @ec2.describe_instances
        node_1_instance = @cloud.find_ec2_node_instance("node-1", instances)
        node_2_instance = @cloud.find_ec2_node_instance("node-2", instances)
        instance_id = @cloud.elastic_ip_association(elastic_ip.publicIp)
        assert instance_id.eql?(node_2_instance.instanceId)
        # case 3: Elastic IP already associated, do nothing
        @cloud.ensure_elastic_ips
        instance_id = @cloud.elastic_ip_association(elastic_ip.publicIp)
        assert instance_id.eql?(node_2_instance.instanceId)
      end
    end

    should "not find a bogus ebs volume allocated" do
      assert_nothing_raised do
        @cloud.connect!
        assert !@cloud.ebs_volume_allocated?("vol-abcd1234")
      end
    end

    should "find an ebs volume allocated" do
      assert_nothing_raised do
        @cloud.connect!
        volume = @ec2.create_volume(:availability_zone => "us-east-1b", :size => "1")
        to_be_watched = [volume.volumeId]
        while !to_be_watched.empty?
          volumes =  @ec2.describe_volumes(:volume_id => to_be_watched[0])
          if volumes.volumeSet.item[0].status.eql? "available"
            to_be_watched.clear
          end
          sleep 5 if !to_be_watched.empty?
        end
        assert @cloud.ebs_volume_allocated?(volume.volumeId)
      end
    end

    should "ensure ebs volumes" do
      assert_nothing_raised do
        @cloud.nodes.delete("lb-1")
        @cloud.elb_nodes.delete("lb-1")
        @cloud.nodes.delete("db-1")
        @cloud.rds_nodes.delete("db-1")
        # case 1: create an EBS volume and attach it to node-1
        volume = @ec2.create_volume(:availability_zone => "us-east-1b", :size => "1")
        to_be_watched = [volume.volumeId]
        while !to_be_watched.empty?
          volumes =  @ec2.describe_volumes(:volume_id => to_be_watched[0])
          if volumes.volumeSet.item[0].status.eql? "available"
            to_be_watched.clear
          end
          sleep 5 if !to_be_watched.empty?
        end
        @cloud.nodes["node-1"].ebs_volume_id(volume.volumeId)
        @cloud.nodes["node-1"].ebs_device("/dev/sdh")
        @cloud.connect!
        @cloud.ensure_ec2_security_groups
        @cloud.ensure_nodes_running
        @cloud.ensure_ebs_volumes
        instances = @ec2.describe_instances
        node_1_instance = @cloud.find_ec2_node_instance("node-1", instances)
        node_2_instance = @cloud.find_ec2_node_instance("node-2", instances)
        instance_id = @cloud.ebs_volume_association(volume.volumeId)
        assert instance_id.eql?(node_1_instance.instanceId)
        # case 2: detach EBS volume from node_1 and attach it to node_2
        @cloud.nodes["node-1"].ebs_volume_id(nil)
        @cloud.nodes["node-1"].ebs_device(nil)
        @cloud.nodes["node-2"].ebs_volume_id(volume.volumeId)
        @cloud.nodes["node-2"].ebs_device("/dev/sdh")
        @cloud.ensure_ebs_volumes
        instance_id = @cloud.ebs_volume_association(volume.volumeId)
        assert instance_id.eql?(node_2_instance.instanceId)
        # case 3: EBS Volumes already associated, do nothing
        @cloud.ensure_ebs_volumes
        instance_id = @cloud.ebs_volume_association(volume.volumeId)
        assert instance_id.eql?(node_2_instance.instanceId)
      end
    end

    should "start clean" do
      assert_nothing_raised do
        elastic_ip = @ec2.allocate_address
        @cloud.nodes["node-1"].elastic_ip(elastic_ip.publicIp)
        volume = @ec2.create_volume(:availability_zone => "us-east-1b", :size => "1")
        to_be_watched = [volume.volumeId]
        while !to_be_watched.empty?
          volumes =  @ec2.describe_volumes(:volume_id => to_be_watched[0])
          if volumes.volumeSet.item[0].status.eql? "available"
            to_be_watched.clear
          end
          sleep 5 if !to_be_watched.empty?
        end
        @cloud.nodes["node-2"].ebs_volume_id(volume.volumeId)
        @cloud.nodes["node-2"].ebs_device("/dev/sdh")
        @cloud.connect!
        @cloud.start
        assert_rds_db_parameter_groups
        assert_ec2_security_groups_created
        assert_role_ec2_security_groups
        assert_rds_db_security_groups
        assert_rds_nodes_running
        assert_ec2_nodes_running
        assert_elb_nodes_running
        instances = @ec2.describe_instances
        node_1_instance = @cloud.find_ec2_node_instance("node-1", instances)
        node_2_instance = @cloud.find_ec2_node_instance("node-2", instances)
        elastic_ip_instance_id = @cloud.elastic_ip_association(elastic_ip.publicIp)
        assert elastic_ip_instance_id.eql?(node_1_instance.instanceId)
        ebs_volume_instance_id = @cloud.ebs_volume_association(volume.volumeId)
        assert ebs_volume_instance_id.eql?(node_2_instance.instanceId)
        # running status code path
        @cloud.status
      end
    end

    should "upload Chef assets" do
      assert_nothing_raised do
        @cloud.connect!
        @cloud.upload_chef_assets
        bucket = AWS::S3::Bucket.find(@cloud.chef_bucket)
        assert !bucket.nil?
        assert !bucket[Maestro::MAESTRO_CHEF_ARCHIVE].nil?
      end
    end

    should "configure nodes" do
      assert_nothing_raised do
        @cloud.nodes.delete("lb-1")
        @cloud.elb_nodes.delete("lb-1")
        @cloud.nodes.delete("db-1")
        @cloud.rds_nodes.delete("db-1")
        @cloud.connect!
        @cloud.start
        @cloud.configure
        assert_ec2_security_groups_created
        assert_role_ec2_security_groups
        assert_ec2_nodes_running
      end
    end

    should "ensure nodes terminated" do
      assert_nothing_raised do
        @cloud.connect!
        @cloud.start
        @cloud.ensure_nodes_terminated
        assert_elb_nodes_not_running
        assert_ec2_nodes_not_running
        assert_rds_nodes_not_running
      end
    end

    should "shutdown clean" do
      assert_nothing_raised do
        @cloud.connect!
        @cloud.start
        @cloud.shutdown
        assert_elb_nodes_not_running
        assert_ec2_nodes_not_running
        assert_rds_nodes_not_running
      end
    end
  end


  ################################
  # Assertion helper methods
  ################################

  # asserts that all of the Cloud's EC2 security groups have been created
  def assert_ec2_security_groups_created
    cloud_security_groups = @cloud.ec2_security_groups
    cloud_security_groups.each do |group_name|
      security_group =  @ec2.describe_security_groups(:group_name => [group_name])
      assert !security_group.nil?
    end
  end

  # asserts that the Cloud's Role EC2 security groups have been configured correctly
  def assert_role_ec2_security_groups
    role_security_groups = @cloud.role_ec2_security_groups
    role_security_groups.each do |group_name|
      security_group =  @ec2.describe_security_groups(:group_name => [group_name])
      assert !security_group.nil?
      if group_name.eql? @cloud.default_ec2_security_group
        assert_default_ec2_security_group(security_group)
      else
        assert_role_ec2_security_group(security_group)
      end
    end
  end

  # asserts the default EC2 security group has been configured correctly
  def assert_default_ec2_security_group(security_group)
    assert !security_group.securityGroupInfo.item[0].ipPermissions.nil?
    assert !security_group.securityGroupInfo.item[0].ipPermissions.item.nil?
    assert !security_group.securityGroupInfo.item[0].ipPermissions.item.empty?
    assert security_group.securityGroupInfo.item[0].ipPermissions.item.size == 4
    ip_permissions = security_group.securityGroupInfo.item[0].ipPermissions.item
    found_default_icmp = false
    found_default_tcp = false
    found_default_udp = false
    found_ssh = false
    ip_permissions.each do |permission|
      if permission.groups.nil?
        assert !permission.fromPort.nil?
        assert permission.fromPort.eql?("22")
        assert !permission.toPort.nil?
        assert permission.toPort.eql?("22")
        assert !permission.ipProtocol.nil?
        assert permission.ipProtocol.eql?("tcp")
        found_ssh = true
      else
        assert !permission.groups.item.nil?
        assert permission.groups.item.size == 1
        assert permission.groups.item[0].groupName.eql?(@cloud.default_ec2_security_group)
        assert permission.groups.item[0].userId.gsub(/-/,'').eql?(@cloud.aws_account_id.gsub(/-/,''))
        if permission.ipProtocol.eql?("icmp")
          found_default_icmp = true
          assert permission.fromPort.eql?("-1")
          assert permission.toPort.eql?("-1")
        elsif permission.ipProtocol.eql?("tcp")
          found_default_tcp = true
          assert permission.fromPort.eql?("1")
          assert permission.toPort.eql?("65535")
        elsif permission.ipProtocol.eql?("udp")
          found_default_udp = true
          assert permission.fromPort.eql?("1")
          assert permission.toPort.eql?("65535")
        end
      end
    end
    assert found_default_icmp
    assert found_default_tcp
    assert found_default_udp
    assert found_ssh
  end

  # asserts a Role EC2 security group is configured correctly
  def assert_role_ec2_security_group(security_group)
    role_security_groups = @cloud.role_ec2_security_groups
    @cloud.roles.values.each do |role|
      role_security_group_name = @cloud.role_ec2_security_group_name(role.name)
      assert !role_security_group_name.nil?
      role_security_group = role_security_groups.find {|group| group.eql? role_security_group_name}
      assert !role_security_group.nil?
      assert !security_group.securityGroupInfo.nil? 
      assert !security_group.securityGroupInfo.item.nil?
      assert !security_group.securityGroupInfo.item.empty?
      if !role.public_ports.nil?
        role.public_ports.each do |port|
          found_port = false
          security_group.securityGroupInfo.item.each do |item|
            if !item.ipPermissions.nil?
              item.ipPermissions.item.each do |permission|
                if permission.fromPort.eql?(port.to_s) && permission.toPort.eql?(port.to_s)
                  found_port = true
                end
              end
              assert found_port
            end
          end
        end
      end
    end
  end

  # asserts that the test Cloud's Ec2 Nodes are running and security groups applied correctly
  def assert_ec2_nodes_running
    instances = @ec2.describe_instances
    @cloud.ec2_nodes.each_pair do |node_name, node|
      instance = @cloud.find_ec2_node_instance(node_name, instances)
      assert !instance.nil?
      this_instance = @ec2.describe_instances(:instance_id => [instance.instanceId])
      assert !this_instance.nil?
      assert this_instance.reservationSet.item.size == 1
      assert this_instance.reservationSet.item[0].groupSet.item.size == node.security_groups.size
      node.security_groups.each do |node_group|
        assert this_instance.reservationSet.item[0].groupSet.item.any? {|group| group.groupId.eql? node_group}
      end
    end
  end

  # asserts that the test Cloud's Nodes are not running
  def assert_ec2_nodes_not_running
    instances = @ec2.describe_instances
    @cloud.ec2_nodes.each_pair do |node_name, node|
      instance = @cloud.find_ec2_node_instance(node_name, instances)
      assert instance.nil?
    end
  end

  # asserts that the test Cloud's Elb Nodes are running and configured correctly
  def assert_elb_nodes_running
    elb_instances = @elb.describe_load_balancers
    @cloud.elb_nodes.each_pair do |node_name, node|
      elb_instance = @cloud.find_elb_node_instance(node_name, elb_instances)
      assert !elb_instance.nil?
      assert elb_instance.LoadBalancerName.eql? node.load_balancer_name
      assert elb_instance.AvailabilityZones.member[0].eql? "us-east-1b"
      assert elb_instance.Listeners.member[0].InstancePort.eql? "80"
      assert elb_instance.Listeners.member[0].Protocol.eql? "HTTP"
      assert elb_instance.Listeners.member[0].LoadBalancerPort.eql? "80"
      assert elb_instance.HealthCheck.HealthyThreshold.eql? "3"
      assert elb_instance.HealthCheck.Timeout.eql? "15"
      assert elb_instance.HealthCheck.UnhealthyThreshold.eql? "5"
      assert elb_instance.HealthCheck.Interval.eql? "60"
      assert !elb_instance.Instances.nil?
      assert !elb_instance.Instances.member.nil?
      assert !elb_instance.Instances.member.empty?
      registered_ec2_instance_ids = Array.new
      elb_instance.Instances.member.each {|member| registered_ec2_instance_ids << member.InstanceId}
      ec2_instances = @ec2.describe_instances
      @cloud.ec2_nodes.each_pair do |ec2_node_name, ec2_node|
        ec2_instance = @cloud.find_ec2_node_instance(ec2_node_name, ec2_instances)
        assert registered_ec2_instance_ids.include?(ec2_instance.instanceId)
      end
      assert node.ec2_nodes.size == registered_ec2_instance_ids.size
    end
  end

  # asserts that the test Cloud's Elb Nodes are not running
  def assert_elb_nodes_not_running
    instances = @elb.describe_load_balancers
    @cloud.elb_nodes.each_pair do |node_name, node|
      instance = @cloud.find_elb_node_instance(node_name, instances)
      assert instance.nil?
    end
  end

  # asserts that the test Cloud's Rds Nodes' db parameter groups are created and configured correctly
  def assert_rds_db_parameter_groups
    @cloud.rds_nodes.each_pair do |name, node|
      params = Hash.new
      node.db_parameters.each {|hash| params[hash[:name]] = hash[:value]}
      begin
        parameters = @rds.describe_db_parameters(:db_parameter_group_name => node.db_parameter_group_name)
        assert !parameters.nil?
        parameters.DescribeDBParametersResult.Parameters.Parameter.each do |p|
          params.delete(p.ParameterName) if params.has_key?(p.ParameterName) && !p.ParameterValue.nil? && params[p.ParameterName].eql?(p.ParameterValue)
        end
        while !parameters.DescribeDBParametersResult.Marker.nil?
          parameters = @rds.describe_db_parameters(:db_parameter_group_name => node.db_parameter_group_name, :marker => parameters.DescribeDBParametersResult.Marker)
          assert !parameters.nil?
          parameters.DescribeDBParametersResult.Parameters.Parameter.each do |p|
            params.delete(p.ParameterName) if params.has_key?(p.ParameterName) && !p.ParameterValue.nil? && params[p.ParameterName].eql?(p.ParameterValue)
          end
        end
      rescue AWS::Error => aws_error
        assert false if aws_error.message.eql? "DBParameterGroup not found: #{node.db_parameter_group_name}"
      end
      assert params.empty?
    end
  end

  # asserts that the test Cloud's Rds Nodes' db security groups are created and configured correctly
  def assert_rds_db_security_groups
    @cloud.rds_nodes.each_pair do |name, node|
      begin
        group = @rds.describe_db_security_groups(:db_security_group_name => node.db_security_group_name)
        assert !group.nil?
        assert group.DescribeDBSecurityGroupsResult.DBSecurityGroups.DBSecurityGroup.EC2SecurityGroups.EC2SecurityGroup.EC2SecurityGroupName.eql? @cloud.default_ec2_security_group
      rescue AWS::Error => aws_error
        assert false if aws_error.message.eql? "DBSecurityGroup not found: #{node.db_security_group_name}"
      end
    end
  end

  # asserts that the test Cloud's Rds Nodes are running and configured correctly
  def assert_rds_nodes_running
    db_instances = @rds.describe_db_instances
    @cloud.rds_nodes.each_pair do |node_name, node|
      rds_instance = @cloud.find_rds_node_instance(node.db_instance_identifier, db_instances)
      assert !rds_instance.nil?
      assert rds_instance.PreferredMaintenanceWindow.eql? node.preferred_maintenance_window.downcase
      assert rds_instance.Engine.eql? node.engine.downcase
      assert rds_instance.MasterUsername.eql? node.master_username
      assert rds_instance.DBInstanceClass.eql? node.db_instance_class
      assert rds_instance.BackupRetentionPeriod.eql? node.backup_retention_period.to_s
      assert rds_instance.DBInstanceIdentifier.eql? node.db_instance_identifier
      assert rds_instance.AllocatedStorage.eql? node.allocated_storage.to_s
      assert rds_instance.AvailabilityZone.eql? node.availability_zone
      assert rds_instance.PreferredBackupWindow.eql? node.preferred_backup_window
    end
  end

  # asserts that the test Cloud's Rds Nodes are not running
  def assert_rds_nodes_not_running
    db_instances = @rds.describe_db_instances
    @cloud.rds_nodes.each_pair do |node_name, node|
      rds_instance = @cloud.find_rds_node_instance(node.db_instance_identifier, db_instances)
      assert rds_instance.nil?
    end
  end
end
