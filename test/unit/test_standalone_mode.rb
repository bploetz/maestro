require 'helper'

# Unit tests for standalone mode
class TestStandaloneMode < Test::Unit::TestCase

  context "Standalone mode" do
    teardown do
      ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
    end
  
    should "be invalid due to missing maestro directory env var" do
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Maestro not configured correctly").nil? }
    end
  
    should "be invalid due to missing maestro directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-missing-maestro')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Maestro config directory does not exist").nil? }
    end
  
    should "be invalid due to maestro not a directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-maestro-not-a-directory')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Maestro config directory is not a directory").nil? }
    end
  
    should "be invalid due to missing clouds directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-missing-clouds')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Maestro clouds config directory does not exist").nil? }
    end

    should "be invalid due to clouds not a directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-clouds-not-a-directory')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Maestro clouds config directory is not a directory").nil? }
    end

    should "be invalid due to missing cookbooks directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-missing-cookbooks')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Chef cookbooks directory does not exist").nil? }
    end

    should "be invalid due to cookbooks not a directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-cookbooks-not-a-directory')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Chef cookbooks directory is not a directory").nil? }
    end

    should "be invalid due to missing roles directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-missing-roles')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Chef roles directory does not exist").nil? }
    end

    should "be invalid due to roles not a directory" do
      ENV[Maestro::MAESTRO_DIR_ENV_VAR] = File.join(File.dirname(__FILE__), 'fixtures', 'invalid-roles-not-a-directory')
      result = Maestro.validate_configs
      assert !result[0], result[1]
      assert result[1].any? {|message| !message.index("Chef roles directory is not a directory").nil? }
    end

  end

end
