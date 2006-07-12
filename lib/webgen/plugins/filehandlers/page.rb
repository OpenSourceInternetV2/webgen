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

require 'webgen/plugins/filehandlers/filehandler'
require 'webgen/listener'
require 'webgen/languages'
require 'webgen/content'
require 'webgen/node'

module FileHandlers

  # Super class for all page description files.
  class PageFileHandler < DefaultFileHandler

    class FragmentNode < Node

      def initialize( parent, path )
        super
        self.meta_info['inMenu'] = false
        self.node_info[:processor] = self
      end

      #TODO: node_for_lang (eg. for menu tag), link_from

      def write_node
        #do nothing
      end

    end

    class PageNode < Node

      def initialize( parent, path, pagedata )
        super( parent, path )
        @meta_info = pagedata.meta_info
        @node_info[:pagedata] = pagedata

        if pagedata.blocks['content']
          @node_info[:pagesections] = pagedata.blocks['content'].sections
          create_fragment_nodes( @node_info[:pagesections] )
        end
      end

=begin
TODO: MOVE TO DOC
- how to resolve page node: via output name, via localized page name or via page name
- only sections of block named 'content' are added to the page node and used for in-page menu when file is read
  only sections already existing are used, sections added later by tags, erb, etc. are not used!
=end

      def =~( path )
        md = /^(#{@path}|#{@node_info[:local_pagename]}|#{@node_info[:pagename]})(?=#|$)/ =~ path
        ( md ? $& : nil )
      end

      #######
      private
      #######

      def create_fragment_nodes( sections )
        sections.each do |s|
          FragmentNode.new( self, '#' + s.id )
          create_fragment_nodes( s.subsections )
        end
      end

    end

    EXTENSION = 'page'

    infos :summary => "Plugin for processing page files"

    param 'defaultLangInFilename', false, 'If true, the output files for the default language ' +
      'will have the language in the file name like all other page files. If false, they won''t.'

    param 'outputNameStyle', [:name, ['.', :lang], '.html'], 'Defines how the output name should ' +
      'be built. The correct name will be used for the :name part and the file language will be ' +
      'used for the :lang part. If <defaultLangInFilename> is true, the :lang part or the ' +
      'subarray in which the :lang part was defined, will be omitted.'

    param 'validator', nil, 'The validator for checking HTML files on their validness. Set ' +
      'to an empty string or nil to prevent checking.'

    param 'defaultPageMetaData',
    {
      'useERB' => true,
      'blocks' => [{'name'=>'content', 'format'=>'textile'}]
    }, 'Specifies the default meta data for page files.'

    handle_extension EXTENSION

    include Listener

    def initialize( plugin_manager )
      super
      add_msg_name( :AFTER_CONTENT_RENDERED )
    end

    def create_node( srcName, parent )
      create_node_from_data( srcName, parent, File.read( srcName ) )
    end

=begin
TODO: move to doc
- lang in meta_info overwrites lang in filename and default lang, orderinfo the same, title the same
- meta info outputNameStyle overwrites parameter outputNameStyle
=end

    def create_node_from_data( filename, parent, data )
      analysed_name = analyse_file_name( filename )

      begin
        data = WebPageData.new( data, @plugin_manager['ContentConverters::DefaultContentConverter'].registered_handlers,
                                Marshal.load( Marshal.dump( param( 'defaultPageMetaData' ) ) ) )
      rescue WebPageDataInvalid => e
        log(:error) { "Invalid page file <#{filename}>: #{e.message}" }
        return nil
      end

      data.meta_info['lang'] ||= analysed_name.lang
      data.meta_info['lang'] = Webgen::LanguageManager.language_for_code( data.meta_info['lang'] )
      data.meta_info['title'] ||= analysed_name.title
      data.meta_info['orderInfo'] ||= analysed_name.orderInfo

      pagename = analysed_name.name + '.' + EXTENSION
      localizedPagename = analysed_name.name + '.' + data.meta_info['lang'] + '.' + EXTENSION

      if node = parent.find {|n| n =~ localizedPagename }
        log(:warn) do
          "Two input files in the same language for one page, " + \
          "using <#{node.node_info[:src]}> instead of <#{filename}>"
        end
      else
        path = create_output_name( analysed_name, data.meta_info['outputNameStyle'] || param( 'outputNameStyle' ) )
        node = PageNode.new( parent, path, data  )
        node.node_info[:src] = analysed_name.filename
        node.node_info[:processor] = self
        node.node_info[:pagename] = pagename
        node.node_info[:local_pagename] = localizedPagename
      end

      node
    end

    def render_node( node, block_name = 'content', use_templates = true )
      chain = [nil]
      content = "{block: #{block_name}}"
      chain << @plugin_manager['FileHandlers::TemplateFileHandler'].templates_for_node( node ) if use_templates
      chain << node

      result = @plugin_manager['Tags::Tags'].substitute_tags( content, chain )
      dispatch_msg( :AFTER_CONTENT_RENDERED, result, node )
      result
    end

    def write_node( node )
      outstring = render_node( node )

      File.open( node.full_path, File::CREAT|File::TRUNC|File::RDWR ) do |file|
        file.write( outstring )
      end

      validator = param( 'validator' )
      validators = @plugin_manager['HtmlValidators::DefaultHtmlValidator'].registered_handlers
      unless validator.nil? || validator == '' || validators[validator].nil?
        validators[validator].validate_file( node.full_path )
      end
    end

    # See DefaultFileHandler#node_for_lang
    def node_for_lang( node, lang )
      node.parent.find {|c| c.node_info[:pagename] == node.node_info[:pagename] && c['lang'] == lang}
    end

    # See DefaultFileHandler#link_from
    def link_from( node, refNode, attr = {} )
      lang_node = node_for_lang( node, refNode['lang'] )
      if lang_node.nil?
        log(:warn) { "Translation of page node <#{node.parent.full_path + node.node_info[:pagename]}> to language '#{refNode['lang']} not found, can't create link"}
        node['title']
      else
        super( lang_node, refNode, attr )
      end
    end


    #######
    private
    #######

=begin
TODO: MOVE TO DOC
- filename format: [orderinfo.]name[.lang].extension
- title is equal to name but with these transformations: _ and - become spaces
- lang part can be two or three characters, otherwise ignored, has to be a ISO-639-2 lang name
=end

    def analyse_file_name( filename )
      matchData = /^(?:(\d+)\.)?([^.]*?)(?:\.(\w\w\w?))?\.(.*)$/.match( File.basename( filename ) )
      analysed = OpenStruct.new

      log(:info) { "Using default language for file <#{filename}>" } if matchData[3].nil?
      analysed.lang      = matchData[3] || param( 'lang', 'CorePlugins::Configuration' )
      analysed.filename  = filename
      analysed.useLangPart  = ( param( 'defaultLangInFilename' ) || param( 'lang', 'CorePlugins::Configuration' ) != analysed.lang )
      analysed.name      = matchData[2]
      analysed.orderInfo = matchData[1].to_i
      analysed.title     = matchData[2].tr('_-', ' ').capitalize
      log(:debug) { analysed.inspect }

      analysed
    end

    def create_output_name( analysed, style, omitLangPart = false )
      style.collect do |part|
        case part
        when String
          part
        when :name
          analysed.name
        when :lang
          analysed.useLangPart && !omitLangPart ? analysed.lang : ''
        when Array
          part.include?( :lang ) && (!analysed.useLangPart || omitLangPart) ? '' : create_output_name( analysed, part, omitLangPart )
        else
          ''
        end
      end.join( '' )
    end

  end

end