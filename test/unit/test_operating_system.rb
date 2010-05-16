require 'helper'

# Unit tests for Maestro::OperatingSystem
class TestOperatingSystem < Test::Unit::TestCase

  context "Maestro::OperatingSystem" do
    setup do
    end

    should "raise an error on invalid etc_issue_str" do
      e = assert_raise(StandardError) {os = Maestro::OperatingSystem.create_from_etc_issue(nil)}
      assert_match(/Invalid etc_issue_str/i, e.message) 
      
      e2 = assert_raise(StandardError) {os = Maestro::OperatingSystem.create_from_etc_issue('')}
      assert_match(/Invalid etc_issue_str/i, e2.message) 
    end
  end

end
