require 'helper'

# Unit tests for Maestro::Node::Base
class TestNode < Test::Unit::TestCase

  context "Maestro::Node::Base" do
    setup do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(File.expand_path(__FILE__)), 'fixtures', 'standalone')
    end
  
    teardown do
      FileUtils.rm_rf([Maestro.maestro_log_directory], :secure => true) if File.exists?(Maestro.maestro_log_directory)
      ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
    end
  
    should "raise exception on space in name" do
      assert_raise StandardError do
        cloud = aws_cloud :test do
          nodes do
            ec2_node "foo bar" do
              roles ["web"]
            end
          end
        end
      end
    end

    should "create log file" do
      assert_nothing_raised do
        base_dir = ENV[Maestro::MAESTRO_DIR_ENV_VAR]
        assert !File.exists?("#{base_dir}/log/maestro/clouds/test/foo.log")
        cloud = aws_cloud :test do
          nodes do
            ec2_node "foo" do
              roles ["web"]
            end
          end
        end
        assert cloud.nodes["foo"].log_file.eql? "#{base_dir}/log/maestro/clouds/test/foo.log"
        assert File.exists?("#{base_dir}/log/maestro/clouds/test/foo.log")
      end
    end
  end
end
