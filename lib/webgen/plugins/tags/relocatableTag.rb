#
#--
#
# $Id$
#
# webgen: a template based web page generator
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

require 'util/ups'
require 'webgen/plugins/tags/tags'

module Tags

  class RelocatableTag < UPS::Plugin

    NAME = 'Relocatable Tag'
    SHORT_DESC = 'Adds a relative path to the specified name if necessary'

    def init
      UPS::Registry['Tags'].tags['relocatable'] = self
    end

    def process_tag( tag, content, node, refNode )
      destNode = refNode.get_node_for_string( content )
      node.get_relpath_to_node( destNode ) + destNode['dest'] unless destNode.nil?
    end

  end

  UPS::Registry.register_plugin RelocatableTag

end