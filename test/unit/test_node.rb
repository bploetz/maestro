require 'helper'

# Unit tests for Maestro::Node
class TestNode < Test::Unit::TestCase

  context "Maestro::Node" do
    setup do
      @cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"

        roles do
          role "web" do
            public_ports [80, 443]
          end
        end
        
        nodes do
          ec2_node "web-1" do
            roles ["web"]
          end
        end
      end
      @node = @cloud.nodes["web-1"]
    end


    should "raise exception on space in name" do
      assert_raise StandardError do
        @cloud = aws_cloud :test do
          keypair_name "XXXXXXX-keypair"
          keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
          roles {}
          nodes do
            ec2_node "foo bar" do
              roles ["web"]
            end
          end
        end
      end
    end

    should "be invalid due to missing role map" do
      @node.roles nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("missing roles map").nil? }
    end
  end
end
