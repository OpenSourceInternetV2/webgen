require 'rexml/document'
require 'plugins/fileHandler/pagePlugin'

class XMLPagePlugin < PagePlugin

    NAME = "XML Page Plugin"
    SHORT_DESC = "Handles XML webpage description files"

    EXTENSION = 'xpage'

    def init
        child_init
    end


    def get_file_data( srcName )
        root = REXML::Document.new( File.new( srcName ) ).root

        #TODO rework this sothat arbitrary tags can be included
        data = Hash.new
        data['title'] = root.text( '/thg/title' )
        data['templateFile'] = root.text('/thg/template') unless root.text('/thg/template').nil?
        data['inMenu'] = root.text('/thg/inMenu') unless root.text('/thg/inMenu').nil?
        data['content'] = ''
        root.elements['content'].each do
            |child| child.write( data['content'] )
        end

        return data
    end

end

UPS::Registry.register_plugin XMLPagePlugin
