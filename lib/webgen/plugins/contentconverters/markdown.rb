#
#--
#
# $Id$
#
# webgen: template based static website generator
# Copyright (C) 2004 Thomas Leitner
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not,
# write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#++
#

begin
  require 'bluecloth'
  require 'webgen/plugins/contentconverters/default'

  module ContentConverters

    # Converts text formatted in Markdown format using BlueCloth to HTML.
    class MarkdownConverter < DefaultContentConverter

      infos :summary => "Handles content formatted in Markdown format using BlueCloth"

      register_handler 'markdown'

      def call( content )
        BlueCloth.new( content ).to_html
      rescue Exception => e
        log(:error) { "Error converting Markdown text to HTML: #{e.message}" }
        content
      end

    end

  end

rescue LoadError => e
  $stderr.puts( "Markdown not available as content format as BlueCloth could not be loaded: #{e.message}" ) if $VERBOSE
end