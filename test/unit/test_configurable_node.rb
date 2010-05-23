require 'helper'

# Unit tests for Maestro::Node::Configurable
class TestConfigurableNode < Test::Unit::TestCase

  context "Maestro::Node::Configurable" do
    setup do
      @cloud = aws_cloud :test do
        nodes do
          ec2_node "web-1" do
            roles ["web"]
          end
        end
      end
      @node = @cloud.nodes["web-1"]
    end


    should "be invalid due to missing role map" do
      @node.roles nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing roles map").nil? }
    end

    should "be invalid due to cookbook_attributes not a string" do
      @node.cookbook_attributes Hash.new
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("cookbook_attributes must be a String").nil? }
    end
  end
end
