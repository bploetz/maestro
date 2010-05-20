require 'helper'

# Unit tests for Maestro class methods
class TestMaestro < Test::Unit::TestCase

  context "Maestro" do

    context "Rails mode" do
      setup do
        Object.const_set("RAILS_ROOT", File.join(File.dirname(File.expand_path(__FILE__)), 'fixtures', 'rails'))
      end

      teardown do
        Object.send(:remove_const, "RAILS_ROOT")
      end

      should "create config dirs" do
        assert_nothing_raised do
          assert_config_directories_do_not_exist("#{RAILS_ROOT}/config")
          Maestro.create_config_dirs
          assert_config_directories_exist("#{RAILS_ROOT}/config")
          delete_config_directories("#{RAILS_ROOT}/config")
          assert_config_directories_do_not_exist("#{RAILS_ROOT}/config")
        end
      end

      should "create log dirs" do
        assert_nothing_raised do
          assert_log_directories_do_not_exist("#{RAILS_ROOT}/log")
          Maestro.create_log_dirs
          assert_log_directories_exist("#{RAILS_ROOT}/log")
          delete_log_directories("#{RAILS_ROOT}/log")
          assert_log_directories_do_not_exist("#{RAILS_ROOT}/log")
        end
      end
      
      should "get clouds" do
        assert_nothing_raised do
          Maestro.clouds
        end
      end
    end


    context "Standalone mode" do
      setup do
        ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(File.expand_path(__FILE__)), 'fixtures', 'standalone')
      end

      teardown do
        ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
      end

      should "create config dirs" do
        assert_nothing_raised do
          base_dir = ENV[Maestro::MAESTRO_DIR_ENV_VAR]
          assert_config_directories_do_not_exist("#{base_dir}/config")
          Maestro.create_config_dirs
          assert_config_directories_exist("#{base_dir}/config")
          delete_config_directories("#{base_dir}/config")
          assert_config_directories_do_not_exist("#{base_dir}/config")
        end
      end

      should "create log dirs" do
        assert_nothing_raised do
          base_dir = ENV[Maestro::MAESTRO_DIR_ENV_VAR]
          assert_log_directories_do_not_exist("#{base_dir}/log")
          Maestro.create_log_dirs
          assert_log_directories_exist("#{base_dir}/log")
          delete_log_directories("#{base_dir}/log")
          assert_log_directories_do_not_exist("#{base_dir}/log")
        end
      end

      should "get clouds" do
        assert_nothing_raised do
          Maestro.clouds
        end
      end
    end

    context "No mode" do
      should "fail to create config dirs" do
        assert_raise RuntimeError do
          Maestro.create_config_dirs
        end
      end

      should "fail to create log dirs" do
        assert_raise RuntimeError do
          Maestro.create_config_dirs
        end
      end

      should "fail to get clouds" do
        assert_raise RuntimeError do
          Maestro.clouds
        end
      end
    end
  end


  def delete_config_directories(dir)
    Dir.rmdir("#{dir}/maestro/roles") if File.exists?("#{dir}/maestro/roles")
    Dir.rmdir("#{dir}/maestro/cookbooks") if File.exists?("#{dir}/maestro/cookbooks")
    Dir.rmdir("#{dir}/maestro/clouds") if File.exists?("#{dir}/maestro/clouds")
    Dir.rmdir("#{dir}/maestro") if File.exists?("#{dir}/maestro")
  end

  def assert_config_directories_exist(dir)
    assert File.exists?("#{dir}/maestro")
    assert File.exists?("#{dir}/maestro/clouds")
    assert File.exists?("#{dir}/maestro/cookbooks")
    assert File.exists?("#{dir}/maestro/roles")
  end

  def assert_config_directories_do_not_exist(dir)
    assert !File.exists?("#{dir}/maestro")
    assert !File.exists?("#{dir}/maestro/clouds")
    assert !File.exists?("#{dir}/maestro/cookbooks")
    assert !File.exists?("#{dir}/maestro/roles")
  end

  def delete_log_directories(dir)
    Dir.rmdir("#{dir}/maestro/clouds") if File.exists?("#{dir}/maestro/clouds")
    Dir.rmdir("#{dir}/maestro") if File.exists?("#{dir}/maestro")
  end

  def assert_log_directories_exist(dir)
    assert File.exists?("#{dir}/maestro")
    assert File.exists?("#{dir}/maestro/clouds")
  end

  def assert_log_directories_do_not_exist(dir)
    assert !File.exists?("#{dir}/maestro")
    assert !File.exists?("#{dir}/maestro/clouds")
  end
end
