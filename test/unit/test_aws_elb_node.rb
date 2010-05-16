require 'helper'

# Unit tests for Maestro::Node::Aws::Elb
class TestAwsElbNode < Test::Unit::TestCase

  context "Maestro::Node::Aws::Elb" do
    setup do
      @cloud = aws_cloud :test do
        roles {}

        nodes do
          ec2_node "web-1" do end

          elb_node "lb-1" do
            availability_zones ["us-east-1b"]
            listeners [{:load_balancer_port => 80, :instance_port => 80, :protocol => "http"}]
            ec2_nodes ["web-1"]
            health_check(:target => "TCP:80", :timeout => 15, :interval => 60, :unhealthy_threshold => 5, :healthy_threshold => 3)
          end
        end
      end
      @node = @cloud.nodes["lb-1"]
    end

    should "be an Elb node" do
      assert @node.is_a? Maestro::Node::Aws::Elb
    end

    should "be invalid due to name too long" do
      cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          elb_node "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX123" do end
        end
      end
      node = cloud.nodes["XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX123"]
      node.validate
      assert !node.valid?
      assert node.validation_errors.any? {|message| !message.index("name must be less than 32 characters").nil?}
    end

    should "be invalid due to name containing invalid characters" do
      "!@\#$%^&*()_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        cloud = aws_cloud :test do
          roles {}
          nodes do
            ec2_node "web-1" do end
            elb_node "#{char}" do end
          end
        end
        node = cloud.nodes["#{char}"]
        node.validate
        assert !node.valid?
        assert node.validation_errors.any? {|message| !message.index("name may only contain alphanumerics and hyphens").nil?}
      end
    end

    should "be invalid due to name not starting with a letter" do
      "0123456789!@\#$%^&*()_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        cloud = aws_cloud :test do
          roles {}
          nodes do
            ec2_node "web-1" do end
            elb_node "#{char}" do end
          end
        end
        node = cloud.nodes["#{char}"]
        node.validate
        assert !node.valid?
        assert node.validation_errors.any? {|message| !message.index("name must start with a letter").nil?}
      end
    end

    should "be invalid due to name ending with hyphen" do
      cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          elb_node "test-" do end
        end
      end
      node = cloud.nodes["test-"]
      node.validate
      assert !node.valid?
      assert node.validation_errors.any? {|message| !message.index("name must not end with a hypen").nil?}
    end

    should "be invalid due to name containing two consecutive hyphens" do
      cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          elb_node "te--st" do end
        end
      end
      node = cloud.nodes["te--st"]
      node.validate
      assert !node.valid?
      assert node.validation_errors.any? {|message| !message.index("name must not contain two consecutive hyphens").nil?}
    end

    should "be invalid due to missing listeners" do
      @node.listeners nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing listeners").nil? }
    end

    should "be invalid due to listeners not an array" do
      @node.listeners "foo"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's listeners must be an Array of Hashes").nil? }
    end

    should "be invalid due to listeners element not a Hash" do
      @node.listeners[0] = "foo"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's listeners must be an Array of Hashes").nil? }
    end

    should "be invalid due to missing load_balancer_port" do
      @node.listeners[0].delete(:load_balancer_port)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's listeners Hash missing :load_balancer_port key").nil? }
    end

    should "be invalid due to missing instance_port" do
      @node.listeners[0].delete(:instance_port)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's listeners Hash missing :instance_port key").nil? }
    end

    should "be invalid due to missing protocol" do
      @node.listeners[0].delete(:protocol)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's listeners Hash missing :protocol key").nil? }
    end

    should "be invalid due to missing ec2_nodes" do
      @node.ec2_nodes nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing ec2_nodes collection").nil? }
    end

    should "be invalid due to ec2_nodes not an array" do
      @node.ec2_nodes 1
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node ec2_nodes collection is not an Array ").nil? }
    end

    should "be invalid due to missing availability_zones" do
      @node.availability_zones nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing availability_zones collection").nil? }
    end

    should "be invalid due to availability_zones not an array" do
      @node.availability_zones 1
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node availability_zones collection is not an Array ").nil? }
    end

    should "be invalid due to health_check element not a Hash" do
      @node.health_check "foo"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's health_check must be a Hash").nil? }
    end

    should "be invalid due to missing target" do
      @node.health_check.delete(:target)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's health_check Hash missing :target key").nil? }
    end

    should "be invalid due to missing timeout" do
      @node.health_check.delete(:timeout)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's health_check Hash missing :timeout key").nil? }
    end

    should "be invalid due to missing interval" do
      @node.health_check.delete(:interval)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's health_check Hash missing :interval key").nil? }
    end

    should "be invalid due to missing unhealthy_threshold" do
      @node.health_check.delete(:unhealthy_threshold)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's health_check Hash missing :unhealthy_threshold key").nil? }
    end

    should "be invalid due to missing healthy_threshold" do
      @node.health_check.delete(:healthy_threshold)
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node's health_check Hash missing :healthy_threshold key").nil? }
    end

    should "be valid" do
      @node.validate
      assert @node.valid?
      assert @node.validation_errors.empty?
    end
  end
end
