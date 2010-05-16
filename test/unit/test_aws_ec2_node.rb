require 'helper'

# Unit tests for Maestro::Node::Aws::Ec2
class TestAwsEc2Node < Test::Unit::TestCase

  context "Maestro::Node::Aws::Ec2" do
    setup do
      @cloud = aws_cloud :test do
        roles do
          role "web" do
            public_ports [80, 443]
          end
        end

        nodes do
          ec2_node "web-1" do
            roles ["web"]
            ami "ami-bb709dd2"
            ssh_user "ubuntu"
            instance_type "m1.small"
            availability_zone "us-east-1b"
            elastic_ip "111.111.11.111"
            ebs_volume_id "vol-XXXXXXXX"
            ebs_device "/dev/sdh"
          end
        end
      end
      @node = @cloud.nodes["web-1"]
    end

    should "be an Ec2 node" do
      assert @node.is_a? Maestro::Node::Aws::Ec2
    end

    should "be invalid due to node missing ami" do
      @node.ami nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing ami").nil? }
    end

    should "be invalid due to node missing instance type" do
      @node.instance_type nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing instance_type").nil? }
    end

    should "be invalid due to node missing availability zone" do
      @node.availability_zone nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing availability_zone").nil? }
    end

    should "be invalid due to node missing ebs_device" do
      @node.ebs_device nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing ebs_device").nil? }
    end

    should "be invalid due to node missing ebs_volume_id" do
      @node.ebs_volume_id nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing ebs_volume_id").nil? }
    end

    should "be valid" do
      @node.validate
      assert @node.valid?
      assert @node.validation_errors.empty?
    end
  end
end
