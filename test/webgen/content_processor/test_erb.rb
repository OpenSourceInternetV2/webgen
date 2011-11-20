# -*- encoding: utf-8 -*-

require 'helper'
require 'webgen/content_processor/erb'

class TestErb < MiniTest::Unit::TestCase

  include Test::WebgenAssertions

  def test_static_call
    website, node, context = Test.setup_content_processor_test
    cp = Webgen::ContentProcessor::Erb

    context.content = "<%= context[:doit] %>6\n<%= context.ref_node.alcn %>\n<%= context.node.alcn %>\n<%= context.dest_node.alcn %><% context.website %>"
    assert_equal("hallo6\n/test\n/test\n/test", cp.call(context).content)

    context.content = "\n<%= 5* %>"
    assert_error_on_line(SyntaxError, 2) { cp.call(context) }
  end

end