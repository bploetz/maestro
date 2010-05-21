require "helper"
require "base_aws"

# Integration tests for Ubuntu
class TestUbuntu < Test::Unit::TestCase

  include BaseAws

  context "Maestro::OperatingSystem::Ubuntu" do

    #######################
    # Setup
    #######################

    setup do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(File.expand_path(__FILE__)), 'fixtures')
      Maestro.create_log_dirs
      credentials = @credentials
      @cloud = aws_cloud :maestro_ubuntu_itest do
        keypair_name credentials[:keypair_name]
        keypair_file credentials[:keypair_file]
        aws_account_id credentials[:aws_account_id]
        aws_access_key credentials[:aws_access_key]
        aws_secret_access_key credentials[:aws_secret_access_key]
        chef_bucket credentials[:chef_bucket]
  
        roles do
        end
  
        nodes do
          ec2_node "ubuntu-itest" do
            instance_type "m1.small"
            availability_zone "us-east-1b"
          end
        end
      end
      @node = @cloud.nodes["ubuntu-itest"]
    end


    #######################
    # Teardown
    #######################

    teardown do
      # terminate instances
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
        puts "Terminating Ubuntu integration test EC2 instances"
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

      # delete ec2 security groups
      cloud_security_groups = @cloud.ec2_security_groups
      cloud_security_groups.each do |group_name|
        @ec2.delete_security_group(:group_name => group_name)
      end

      FileUtils.rm_rf([Maestro.maestro_log_directory], :secure => true) if File.exists?(Maestro.maestro_log_directory)
      ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
    end


    #######################
    # Tests
    #######################

    context "Ubuntu 10.04" do
      should "install chef-solo" do
        @node.ami "ami-2d4aa444"
        @node.ssh_user "ubuntu"
        assert_nothing_raised do
          @cloud.connect!
          @cloud.start
          @cloud.get_configurable_node_hostnames
          assert !@cloud.chef_solo_installed?[0]
          @cloud.install_chef_solo
          assert @cloud.chef_solo_installed?[0]
        end
      end
    end

    context "Ubuntu 9.10" do
      should "install chef-solo" do
        @node.ami "ami-bb709dd2"
        @node.ssh_user "ubuntu"
        assert_nothing_raised do
          @cloud.connect!
          @cloud.start
          @cloud.get_configurable_node_hostnames
          assert !@cloud.chef_solo_installed?[0]
          @cloud.install_chef_solo
          assert @cloud.chef_solo_installed?[0]
        end
      end
    end

    context "Ubuntu 9.04" do
      should "install chef-solo" do
        @node.ami "ami-ccf615a5"
        @node.ssh_user "root"
        assert_nothing_raised do
          @cloud.connect!
          @cloud.start
          @cloud.get_configurable_node_hostnames
          assert !@cloud.chef_solo_installed?[0]
          @cloud.install_chef_solo
          assert @cloud.chef_solo_installed?[0]
        end
      end
    end

    context "Ubuntu 8.10" do
      should "install chef-solo" do
        @node.ami "ami-c0f615a9"
        @node.ssh_user "root"
        assert_nothing_raised do
          @cloud.connect!
          @cloud.start
          @cloud.get_configurable_node_hostnames
          assert !@cloud.chef_solo_installed?[0]
          @cloud.install_chef_solo
          assert @cloud.chef_solo_installed?[0]
        end
      end
    end

    context "Ubuntu 8.04" do
      should "install chef-solo" do
        @node.ami "ami-c4f615ad"
        @node.ssh_user "root"
        assert_nothing_raised do
          @cloud.connect!
          @cloud.start
          @cloud.get_configurable_node_hostnames
          assert !@cloud.chef_solo_installed?[0]
          @cloud.install_chef_solo
          assert @cloud.chef_solo_installed?[0]
        end
      end
    end
  end
end
