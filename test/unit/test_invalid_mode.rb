require 'helper'

# Unit tests for no mode found
class TestInvalidMode < Test::Unit::TestCase

  should "be invalid due to no rails or standalone" do
    result = Maestro.validate_configs
    assert !result[0]
    assert result[1].any? {|message| !message.index("Maestro not configured correctly.").nil? }
  end

end
