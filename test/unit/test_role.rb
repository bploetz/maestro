require 'helper'

# Unit tests for Maestro::Role
class TestRole < Test::Unit::TestCase

  context "Maestro::Role" do
    setup do
      @cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"

        roles do
          role "web" do
            public_ports [80, 443]
          end
        end
        nodes {}
      end
      @role = @cloud.roles["web"]
    end


    should "raise exception on space in name" do
      assert_raise StandardError do
        @cloud = aws_cloud :test do
          keypair_name "XXXXXXX-keypair"
          keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
  
          roles do
            role "foo bar" do
              public_ports [80, 443]
            end
          end
          nodes {}
        end
      end
    end
    
    should "be invalid due to public_ports not being an Array" do
      @role.public_ports String.new
      @role.validate
      assert !@role.valid?
      assert @role.validation_errors.any? {|message| !message.index("public_ports attribute must be an Array (found String)").nil? }
    end

    should "be invalid due to public_ports containing a non-number" do
      @role.public_ports ["foo", "bar"]
      @role.validate
      assert !@role.valid?
      assert @role.validation_errors.any? {|message| !message.index("public_ports attribute must be an Array of numbers").nil? }
    end

    should "be valid" do
      @role.validate
      assert @role.valid?
      assert @role.validation_errors.empty?
    end
  end
end
