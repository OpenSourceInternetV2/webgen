# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'webgen/error'

class TestError < MiniTest::Unit::TestCase

  def test_all
    e = Webgen::Error.new("test")
    assert_match(/Error:/, e.message)

    e = Webgen::Error.new("test", 'location')
    assert_equal('location', e.location)
    assert_match(/Error at location:/, e.message)

    e = Webgen::Error.new("test", 'location', '/path')
    assert_equal('location', e.location)
    assert_equal('/path', e.path)
    assert_match(/Error at location while working on <\/path>:/, e.message)

    e = Webgen::Error.new(Exception.new("test"))
    assert_match(/Error:.*test/m, e.message)
  end

  def test_class_error_line
    begin
      eval("5 =")
    rescue SyntaxError => e
      assert_equal(1, Webgen::Error.error_line(e))
    end

    begin
      eval("x = 5\n raise 'hallo'", binding, __FILE__, 1)
    rescue
      assert_equal(2, Webgen::Error.error_line($!))
    end
  end

end

class TestNodeCreationError < MiniTest::Unit::TestCase

  def test_all
    e = Webgen::NodeCreationError.new("test")
    assert_match(/Error while creating a node:/, e.message)
  end

end

class TestRenderError < MiniTest::Unit::TestCase

  def test_all
    e = Webgen::RenderError.new("test", 'location', '/path', '/error')
    assert_equal("/error", e.error_path)
    assert_match(/Error at location in <\/error> while rendering <\/path>/, e.message)

    e = Webgen::RenderError.new('test', 'location', '/path', '/error', 5)
    assert_equal("/error", e.error_path)
    assert_match(/Error at location in <\/error:~5> while rendering <\/path>/, e.message)

    begin
      eval("5 =")
    rescue SyntaxError
      e = Webgen::RenderError.new($!, 'location', '/path', '/error')
      assert_equal("/error", e.error_path)
      assert_match(/Error at location in <\/error:~1> while rendering <\/path>/, e.message)
    end
  end

end

class TestLoadError < MiniTest::Unit::TestCase

  def test_all
    e = Webgen::LoadError.new(Exception.new("something"), 'location', '/path')
    assert_nil(e.library)
    assert_nil(e.gem)
    assert_match(/Error at location while working on <\/path>:.*something/m, e.message)

    e = Webgen::LoadError.new("test", 'location', '/path')
    assert_equal("test", e.library)
    assert_nil(e.gem)
    assert_match(/Error at location while working on <\/path>:.*The needed library 'test' is missing/m, e.message)

    e = Webgen::LoadError.new("test", 'location', '/path', 'gem')
    assert_equal("test", e.library)
    assert_equal('gem', e.gem)
    assert_match(/Error at location while working on <\/path>:.*The needed library 'test' is missing.*gem install gem/m, e.message)
  end

end

class TestCommandNotFoundError < MiniTest::Unit::TestCase

  def test_all
    e = Webgen::CommandNotFoundError.new("test", 'location', '/path')
    assert_equal("test", e.cmd)
    assert_match(/Error at location while working on <\/path>:.*The needed command 'test' is missing/m, e.message)
  end

end