# -*- encoding: utf-8 -*-

require 'helper'
require 'webgen/destination/file_system'
require 'webgen/path'
require 'tmpdir'
require 'fileutils'
require 'stringio'

class TestDestinationFileSystem < MiniTest::Unit::TestCase

  def setup
    @website = MiniTest::Mock.new
    @dir = File.join(Dir.tmpdir, 'test-webgen')
    @website.expect(:directory, @dir)
  end

  def test_initialize
    dest = Webgen::Destination::FileSystem.new(@website, 'test')
    assert_equal(File.join(@dir, 'test'), dest.root)
    dest = Webgen::Destination::FileSystem.new(@website, '/tmp/hallo')
    assert_equal('/tmp/hallo', dest.root)
    dest = Webgen::Destination::FileSystem.new(@website, '../hallo')
    assert_equal(File.expand_path(File.join(@dir, '../hallo')), dest.root)
    @website.verify
  end

  def test_file_methods
    dest = Webgen::Destination::FileSystem.new(@website, 'test')
    assert(!dest.exists?('/dir/hallo'))

    dest.write('/dir/hallo', 'content', :file)
    assert(File.file?(File.join(dest.root, 'dir/hallo')))
    assert(dest.exists?('/dir/hallo'))
    assert_equal('content', File.read(File.join(dest.root, 'dir/hallo')))
    assert_equal('content', dest.read('/dir/hallo'))

    dest.delete('/dir/hallo')
    refute(dest.exists?('/dir/hallo'))

    dest.write('/dir/hallo', Webgen::Path.new('fu') { StringIO.new("contentö")}, :file)
    assert(dest.exists?('/dir/hallo'))
    assert_equal('contentö', dest.read('/dir/hallo', 'r'))
    assert_equal('contentö', File.read(File.join(dest.root, 'dir/hallo')))

    dest.delete('/dir')
    refute(dest.exists?('/dir'))

    dest.write('/dir', '', :directory)
    assert(File.directory?(File.join(dest.root, 'dir')))

    assert_raises(RuntimeError) { dest.write('other', '', :unknown) }
  ensure
    FileUtils.rm_rf(@dir)
  end

end
