require File.dirname(__FILE__) + '/../test_helper'

class ImageTest < Test::Unit::TestCase
  fixtures :images

  def test_invalid_with_blank_image
    image = Image.new(:batch => true)
    assert !image.valid?
    assert image.errors.invalid?(:name)
    assert image.errors.invalid?(:magnification)
  end
  
end
