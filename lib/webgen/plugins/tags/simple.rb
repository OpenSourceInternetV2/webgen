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

require 'webgen/plugins/tags/tags'

module Tags

  # Loads tag definitions from a file for project specific tags.
  class TagLoader < DefaultTag

    plugin "Date Tag"
    summary "Prints out the date"
    add_param 'format', '%A, %B %d %H:%M:%S %Z %Y', 'The format of the date (same options as Time#strftime).'
    depends_on 'Tags'

    def initialize
      super
      register_tag( 'date' )
    end

    def process_tag( tag, node, refNode )
      Time.now.strftime( get_param( 'format' ) )
    end

  end

end
