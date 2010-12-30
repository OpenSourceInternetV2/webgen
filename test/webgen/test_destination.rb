# -*- encoding: utf-8 -*-

require 'minitest/autorun'
require 'webgen/destination'

class Webgen::Destination::MyDestination

  def call(context)
    raise Webgen::Error.new('msg') if context == 'webgen'
    raise 'msg' if context == 'error'
    context + 'value'
  end

end

class TestDestination < MiniTest::Unit::TestCase

  def setup
    @dest = Webgen::Destination.new
  end

  def test_register
    @dest.register('Webgen::Destination::MyDestination')
    assert(@dest.registered?('my_destination'))

    @dest.register('MyDestination')
    assert(@dest.registered?('my_destination'))

    @dest.register('MyDestination', :name => 'test')
    assert(@dest.registered?('test'))

    assert_raises(ArgumentError) { @dest.register('doit') { "nothing" } }
  end

  def test_instance
    @dest.register('MyDestination')
    website = MiniTest::Mock.new
    @dest.website = website

    website.expect(:config, {'destination' => 'unknown'})
    assert_raises(Webgen::Error) { @dest.instance_eval { instance } }
    website.verify

    website.expect(:config, {'destination' => 'my_destination'})
    assert_kind_of(Webgen::Destination::MyDestination, @dest.instance_eval { instance })
    website.verify

    website.expect(:config, {'destination' => 'unknown'})
    @dest.instance_eval { instance } # nothing should be raised
    website.verify
  end

end