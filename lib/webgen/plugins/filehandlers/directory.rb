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

load_plugin 'webgen/plugins/filehandlers/filehandler.rb'
require 'webgen/node'

module FileHandlers

  # Handles directories.
  class DirectoryHandler < DefaultHandler

    # Specialized node for a directory.
    class DirNode < Node

      def initialize( parent, path, meta_info = {} )
        super( parent, path )
        self.meta_info = meta_info
        self['title'] = File.basename( path ).capitalize
      end

      def []( name )
        process_dir_index if name == 'indexFile' &&
          (!self.meta_info.has_key?( 'indexFile' ) ||
           (!self.meta_info['indexFile'].nil? && !self.meta_info['indexFile'].kind_of?( Node ) ) )
        super
      end

      def order_info
        (super != 0 || self['indexFile'].nil?) ? super : self['indexFile'].order_info
      end

      #######
      private
      #######

      def process_dir_index
        indexFile = self.meta_info['indexFile']
        if indexFile.nil?
          self['indexFile'] = nil
        else
          node = resolve_node( indexFile )
          if node
            node_info[:processor].log(:info) { "Directory index file for <#{self.full_path}> => <#{node.full_path}>" }
            self['indexFile'] = node
          else
            node_info[:processor].log(:warn) { "No directory index file found for directory <#{self.full_path}>" }
            self['indexFile'] = nil
          end
        end
      end

    end


    infos( :name => 'File/DirectoryHandler',
           :author => Webgen::AUTHOR,
           :summary => "Handles directories"
           )

    default_meta_info( { 'indexFile' => 'index.page' } )

    register_path_pattern '**/', 0


    # Returns a new DirNode.
    def create_node( path, parent, meta_info )
      filename = File.basename( path ) + '/'
      if parent.nil? || (node = parent.find {|child| child =~ filename }).nil?
        node = DirNode.new( parent, filename, meta_info )
        node.node_info[:processor] = self
        node.node_info[:src] = path
      end
      node
    end

    # Creates the directory (and all its parent directories if necessary).
    def write_node( node )
      FileUtils.makedirs( node.full_path ) unless File.exists?( node.full_path )
    end

    # Return the page node for the directory +node+ using the specified language +lang+. If an
    # index file is specified, then the its correct language node is returned, else +node+ is
    # returned.
    def node_for_lang( node, lang )
      langnode = node['indexFile'].node_for_lang( lang ) if node['indexFile']
      langnode || node
    end

    def link_from( node, ref_node, attr = {} )
      lang_node = (attr[:resolve_lang_node] == false ? node : node.node_for_lang( ref_node['lang'] ) )
      attr[:link_text] ||=  lang_node['directoryName'] || node['title']
      super( lang_node, ref_node, attr )
    end

    # Recursively creates a given directory path starting from the path of +parent+ and returns the
    # bottom most directory node.
    def recursive_create_path( path, parent )
      path.split( File::SEPARATOR ).each do |pathname|
        case pathname
        when '.' then  #do nothing
        when '..' then parent = parent.parent
        else parent = @plugin_manager['Core/FileHandler'].create_node( pathname, parent, self )
        end
      end
      parent
    end

  end

end
