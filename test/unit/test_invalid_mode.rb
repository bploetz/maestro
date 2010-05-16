require 'helper'

# Unit tests for no mode found
class TestInvalidMode < Test::Unit::TestCase

  should "be invalid due to no rails or standalone" do
    result = Maestro.validate_configs
    assert !result[0], result[1]
  end

end
