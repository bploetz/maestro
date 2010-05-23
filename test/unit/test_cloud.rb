require 'helper'

# Unit tests for Maestro::Cloud
class TestCloud < Test::Unit::TestCase

  context "Maestro::Cloud" do
    should "return raise error due to unsupported cloud method" do
      assert_raise NoMethodError do
        @cloud = bogus_cloud :test do
        end
      end
    end
  end

  context "A Cloud instance" do
    setup do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(File.expand_path(__FILE__)), 'fixtures', 'standalone')
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
    end

    teardown do
      FileUtils.rm_rf([Maestro.maestro_log_directory], :secure => true) if File.exists?(Maestro.maestro_log_directory)
      ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
    end


    should "raise exception on space in name" do
      assert_raise StandardError do
        @cloud = aws_cloud "foo bar" do
          keypair_name "XXXXXXX-keypair"
          keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
          roles {}
          nodes {}
        end
      end
    end

    should "be invalid due to missing keypair name" do
      @cloud.keypair_name nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing keypair_name").nil? }
    end

    should "be invalid due to missing keypair file" do
      @cloud.keypair_file nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing keypair_file").nil? }
    end

    should "be invalid due to missing roles" do
      @cloud.roles = nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing roles").nil? }
    end

    should "allow dynamic role creation" do
      cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"

        roles do
          3.times do |i|
            role "web-#{i+1}" do
              public_ports [80, 443]
            end
          end
        end
        nodes {}
      end
      assert cloud.roles.size == 3
    end

    should "allow dynamic node creation" do
      cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
        roles {}
        nodes do
          7.times do |i|
            ec2_node "web-#{i+1}" do
              roles ["web"]
            end
          end
        end
      end
      assert cloud.nodes.size == 7
    end

    should "be invalid due to duplicate roles" do
      cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"

        roles do
          role "web" do
            public_ports [80, 443]
          end
          role "web" do
            public_ports [80, 443]
          end
        end
        nodes {}
      end
      cloud.validate
      assert !cloud.valid?
      assert cloud.validation_errors.any? {|message| !message.index("Duplicate role definition: web").nil?}
    end

    should "be invalid due to invalid roles, public-ports not an array" do
      @cloud.roles["web"].public_ports 3
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("public_ports attribute must be an Array").nil? }
    end

    should "be invalid due to invalid roles, public-ports not numbers" do
      @cloud.roles["web"].public_ports [3, Hash.new]
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("public_ports attribute must be an Array of numbers").nil? }
    end

    should "be invalid due to missing nodes" do
      @cloud.nodes = nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing nodes").nil? }
    end

    should "create logs" do
      assert_nothing_raised do
        base_dir = ENV[Maestro::MAESTRO_DIR_ENV_VAR]
        assert !File.exists?("#{base_dir}/log/maestro/clouds/foo")
        assert !File.exists?("#{base_dir}/log/maestro/clouds/foo/foo.log")
        cloud = aws_cloud :foo do end
        assert cloud.log_file.eql? "#{base_dir}/log/maestro/clouds/foo/foo.log"
        assert cloud.log_directory.eql? "#{base_dir}/log/maestro/clouds/foo"
        assert File.exists?("#{base_dir}/log/maestro/clouds/foo/foo.log")
        assert File.exists?("#{base_dir}/log/maestro/clouds/foo")
      end
    end
  end
end
