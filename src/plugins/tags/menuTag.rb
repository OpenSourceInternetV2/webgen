require 'ups/ups'
require 'node'
require 'plugins/tags/tags'

class MenuTag < UPS::Plugin

    NAME = 'Menu Tag'
    SHORT_DESC = 'Builds up a menu'

    def init
        UPS::Registry['Tags'].tags['menu'] = self
    end


	def process_tag( tag, content, node, templateNode )
        if !defined? @menuTree
            @menuTree = create_menu_tree( Node.root( node ), nil )
            UPS::Registry['Tree Transformer'].execute @menuTree unless @menuTree.nil?
        end
        build_menu( node, @menuTree, content['level'] )
	end

    #######
    private
    #######

    def build_menu( srcNode, node, level )
        return '' unless level >= 1

        out = '<ul>'
        node.each do |child|
            if child.kind_of? MenuNode
                submenu = child['node'].kind_of?( DirNode ) ? build_menu( srcNode, child, level - 1 ) : ''
                before, after = menu_entry( srcNode, child['node'] )
            else
                submenu = ''
                before, after = menu_entry( srcNode, child )
            end

            out << before
            out << submenu
            out << after
        end
        out << '</ul>'

        return out
    end


    def menu_entry( srcNode, node )
        langNode = node['processor'].get_lang_node( node, srcNode['lang'] )
        isDir = node.kind_of? DirNode

        styles = []
        styles << 'submenu' if isDir
        styles << 'selectedMenu' if !isDir && langNode.recursive_value( 'dest' ) == srcNode.recursive_value( 'dest' )

        style = " class=\"#{styles.join(',')}\"" if styles.length > 0
        link = langNode['processor'].get_html_link( langNode, srcNode, ( isDir ? langNode['directoryName'] : langNode['title'] ) )

        if styles.include? 'submenu'
            before = "<li#{style}>#{link}"
            after = "</li>"
        else
            before = "<li#{style}>#{link}</li>"
            after = ""
        end

        self.logger.debug { [before, after] }
        return before, after
    end


    class MenuNode < Node

        def initialize( parent, node )
            super parent
            self['title'] = 'Menu: '+ node['title']
            self['isMenuNode'] = true
            self['virtual'] = true
            self['node'] = node
        end

    end


    def create_menu_tree( node, parent )
        menuNode = MenuNode.new( parent, node )

        node.each do |child|
            menu = create_menu_tree( child, menuNode )
            menuNode.add_child menu unless menu.nil?
        end

        return menuNode.has_children? ? menuNode : ( put_node_in_menu?( node ) ? node : nil )
    end


    def put_node_in_menu?( node )
        inMenu = node['inMenu']
        inMenu ||=  node.parent && node.parent['pagePlugin:basename'] &&
                    node.parent.find do |child| child['inMenu'] end
        inMenu &&= !node['virtual']
        inMenu
    end

end

UPS::Registry.register_plugin MenuTag