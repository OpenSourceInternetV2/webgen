# -*- encoding: utf-8 -*-

require 'uri'
require 'webgen/languages'

module Webgen

  # == About
  #
  # A Path object provides information about a path that is used to create one or more nodes as well
  # as methods for accessing/modifying the path's content. Path objects are created by Source
  # classes but can also be created during the rendering phase (see
  # PathHandler#create_secondary_nodes).
  #
  # So a Path object always refers to a path from which nodes are created! In contrast, destination
  # paths are just strings and specify the location where a specific node should be written to (see
  # Node#destination_path).
  #
  # A Path object can represent one of three different things: a directory, a file or a fragment. If
  # the +path+ ends with a slash character, then the path object represents a directory, if the path
  # contains a hash character anywhere, then the path object represents a fragment and else it
  # represents a file. Have a look at the user documentation to see the exact format that can be
  # used for a path string!
  #
  # == Utility methods
  #
  # The Path class also provides some general methods for working with path strings which are also
  # used, for example, by the Node class:
  #
  # * Path.url
  # * Path.append
  # * Path.matches_pattern?
  # * Path.lcn
  #
  class Path

    # This pattern is the the same as URI::UNSAFE except that the hash character (#) is also
    # not escaped. This is needed so that paths with fragments work correctly.
    URL_UNSAFE_PATTERN = Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}#]") # :nodoc:

    # Base URI prepended to all internal URLs.
    WEBGEN_BASE_URI = URI.parse('webgen://webgen.localhost/') # :nodoc:

    # Construct an internal URL for the given +path+ which can be an acn/alcn/absolute path.
    #
    # If the parameter +make_absolute+ is +true+, then a relative URL will be made absolute by
    # prepending the special URL 'webgen://webgen.localhost/'.
    def self.url(path, make_absolute = true)
      url = URI.parse(URI::DEFAULT_PARSER.escape(path, URL_UNSAFE_PATTERN))
      url = WEBGEN_BASE_URI + url unless url.absolute? || !make_absolute
      url
    end

    # Append the +path+ to the +base+ path.
    #
    # The +base+ parameter has to be an acn/alcn/absolute path. If it represents a directory, it
    # needs to have a trailing slash! The +path+ parameter doesn't need to be absolute and may
    # contain path patterns.
    def self.append(base, path)
      raise(ArgumentError, 'base needs to start with a slash (i.e. be an absolute path)') unless base[0] == ?/
      url = url(base) + url(path, false)
      (url.path << (url.fragment.nil? ? '' : "##{url.fragment}")).encode!(path.encoding)
    end

    # Return +true+ if the given path string matches the given path pattern.
    #
    # If a fragment path (i.e. one which has a hash character somewhere) should be matched, the
    # pattern needs to have a hash character as well.
    #
    # For information on which patterns are supported, have a look at the API documentation of
    # File.fnmatch.
    def self.matches_pattern?(path, pattern, options = File::FNM_DOTMATCH|File::FNM_CASEFOLD|File::FNM_PATHNAME)
      pattern += '/' if path =~ /\/$/ && pattern !~ /\/$|^$/
      (path.to_s.include?('#') ? pattern.include?('#') : true) && File.fnmatch(pattern, path, options)
    end

    # Construct a localized canonical name from a given canonical name and a language.
    def self.lcn(cn, lang)
      if lang.nil?
        cn
      else
        cn.split('.').insert((cn =~ /^\./ ? 2 : 1), lang.to_s).join('.')
      end
    end


    include Comparable

    # Create a new Path object for +path+ (a string).
    #
    # The optional block needs to return an IO object for getting the content of the path (see #io
    # and #data).
    #
    # The +path+ string needs to be in a well defined format which can be looked up in the webgen
    # user documentation.
    def initialize(path, meta_info = {}, &ioblock)
      @path = path.freeze
      @meta_info = meta_info.dup
      @ioblock = block_given? ? ioblock : nil
    end

    def initialize_copy(orig) #:nodoc:
      super
      @meta_info = orig.instance_variable_get(:@meta_info).dup
    end

    # The original path string from which this Path object was created.
    attr_reader :path

    # Meta information about the path.
    #
    # Triggers analyzation of the path if invoked. See #[]= to setting meta information without
    # triggering analyzation.
    def meta_info
      defined?(@basename) ? @meta_info : (analyse; @meta_info)
    end

    # Get the value of the meta information key.
    #
    # This method has to be used to get meta information without triggering analyzation of the path
    # string!
    def [](key)
      @meta_info[key]
    end

    # Set the meta information +key+ to +value+.
    #
    # This method has to be used to set meta information without triggering analyzation of the path
    # string!
    def []=(key, value)
      @meta_info[key] = value
    end

    # The string specifying the parent path.
    #
    # Triggers analyzation of the path if invoked.
    def parent_path
      defined?(@parent_path) ? @parent_path : (analyse; @parent_path)
    end

    # The canonical name of the path without the extension.
    #
    # Triggers analyzation of the path if invoked.
    def basename
      defined?(@basename) ? @basename : (analyse; @basename)
    end

    # The extension of the path.
    #
    # Triggers analyzation of the path if invoked.
    def ext
      defined?(@ext) ? @ext : (analyse; @ext)
    end

    # Set the extension of the path.
    #
    # Triggers analyzation of the path if invoked.
    def ext=(value)
      defined?(@ext) || analyse
      @ext = value
    end

    # The canonical name created from the +path+ (namely from the parts +basename+ and +extension+
    # as well as the meta information +version+).
    #
    # Triggers analyzation of the path if invoked.
    def cn
      if meta_info['cn']
        tmp_cn = custom_cn
      else
        tmp_cn = basename.dup << (use_version_for_cn? ? "-#{meta_info['version']}" : '') <<
          (ext.length > 0 ? ".#{ext}" : '')
      end
      tmp_cn << (@path =~ /.\/$/ ? '/' : '')
    end

    # The localized canonical name created from the +path+.
    #
    # Triggers analyzation of the path if invoked.
    def lcn
      self.class.lcn(cn, meta_info['lang'])
    end

    # The absolute canonical name of this path.
    #
    # Triggers analyzation of the path if invoked.
    def acn
      if @path =~ /#/
        self.class.new(parent_path).acn << cn
      else
        parent_path + cn
      end
    end

    # The absolute localized canonical name of this path.
    #
    # Triggers analyzation of the path if invoked.
    def alcn
      if @path =~ /#/
        self.class.new(parent_path).alcn << lcn
      else
        parent_path + lcn
      end
    end


    # Mount this path at the mount point +mp+, optionally stripping +prefix+ from the parent path,
    # and return the new Path object.
    #
    # The parameters +mp+ and +prefix+ have to be absolute directory paths, ie. they have to start
    # and end with a slash and must not contain any hash characters!
    #
    # Also note that mounting a path is not possible once it is fully initialized, i.e. once some
    # information extracted from the path string is accessed.
    def mount_at(mp, prefix = nil)
      raise(ArgumentError, "Can't mount a fully initialized path") if defined?(@basename)
      raise(ArgumentError, "The mount point (#{mp}) must be a valid directory path") if mp =~ /^[^\/]|#|[^\/]$/
      raise(ArgumentError, "The strip prefix (#{prefix}) must be a valid directory path") if !prefix.nil? && prefix =~ /^[^\/]|#|[^\/]$/

      temp = self.class.new(File.join(mp, @path.sub(/^#{Regexp.escape(prefix.to_s)}/, '')), @meta_info, &@ioblock)
      temp
    end

    # Provide access to the IO object of the path by yielding it.
    #
    # After the method block returns, the IO object is automatically closed. An error is raised, if
    # no IO object is associated with the Path instance.
    #
    # The parameter +mode+ specifies the mode in which the IO object should be opened. This can be
    # used, for example, to specify a certain input encoding or to use binary mode.
    def io(mode = 'r') # :yields: io
      raise "No IO object defined for the path #{self}" if @ioblock.nil?
      io = @ioblock.call(mode)
      yield(io)
    ensure
      io.close if io
    end

    # Return the content of the IO object of the path as string.
    #
    # For a description of the parameter +mode+ see #io.
    #
    # An error is raised, if no IO object is associated with the Path instance.
    def data(mode = 'r')
      io(mode) {|io| io.read}
    end

    # Set the IO block to the provided block.
    def set_io(&block)
      @ioblock = block
    end

    # Equality -- Return +true+ if +other+ is a Path object with the same #path or if +other+ is a
    # String equal to the #path. Else return +false+.
    def ==(other)
      if other.kind_of?(Path)
        other.path == @path
      elsif other.kind_of?(String)
        other == @path
      else
        false
      end
    end
    alias_method(:eql?, :==)

    # Compare the #path of this object to 'other.path'.
    def <=>(other)
      @path <=> other.to_str
    end

    def hash #:nodoc:
      @path.hash
    end

    def to_s #:nodoc:
      @path
    end
    alias_method :to_str, :to_s

    def inspect #:nodoc:
      "#<Path: #{@path}>"
    end

    #######
    private
    #######

    # Analyse the path and extract the needed information.
    def analyse
      if @path =~ /#/
        analyse_fragment
      elsif @path =~ /\/$/
        analyse_directory
      else
        analyse_file
      end
      @meta_info['title'] ||= @basename.tr('_-', ' ').capitalize
      @ext ||= ''
      raise "The basename of a path may not be empty: #{@path}" if @basename.empty? || @basename == '#'
      raise "The parent path must start with a slash: #{@path}" if @path !~ /^\//
    end

    # Analyse the path assuming it is a directory.
    def analyse_directory
      @parent_path = (@path == '/' ? '' : File.join(File.dirname(@path), '/'))
      @basename = File.basename(@path)
    end

    FILENAME_RE = /^(?:(\d+)\.)?(\.?[^.]*?)(?:\.(\w\w\w?)(?=\.))?(?:\.(.*))?$/ #:nodoc:

    # Analyse the path assuming it is a file.
    def analyse_file
      @parent_path = File.join(File.dirname(@path), '/')
      match_data = FILENAME_RE.match(File.basename(@path))

      if !match_data[1].nil? && match_data[3].nil? && match_data[4].nil? # handle special case of sort_info.basename as basename.ext
        @basename = match_data[1]
        @ext = match_data[2]
      else
        @meta_info['sort_info'] ||= match_data[1].to_i unless match_data[1].nil?
        @basename               = match_data[2]
        @meta_info['lang']      ||= Webgen::LanguageManager.language_for_code(match_data[3]) if match_data[3]
        @ext                    = (@meta_info['lang'].nil? && !match_data[3].nil? ? match_data[3] << '.' : '') << match_data[4].to_s
      end
    end

    # Analyse the path assuming it is a fragment.
    def analyse_fragment
      @parent_path, @basename =  @path.scan(/^(.*?)(#.*?)$/).first
      raise "The parent path of a fragment path must be a file path and not a directory path: #{@path}" if @parent_path =~ /\/$/
      raise "A fragment path must only contain one hash character: #{path}" if @path.count("#") > 1
    end

    # Whether the version information should be added to the cn?
    def use_version_for_cn?
      meta_info['version'] && meta_info['version'] != 'default'
    end

    CN_SEGMENTS = /<.*?>|\(.*?\)/ # :nodoc:

    # Construct a custom canonical name given by the 'cn' meta information.
    def custom_cn
      replace_segment = lambda do |match|
        case match
        when "<basename>"
          basename
        when "<ext>"
          ext.empty? ? '' : '.' << ext
        when "<version>"
          use_version_for_cn? ? meta_info['version'] : ''
        when /\((.*)\)/
          inner = $1
          replaced = inner.gsub(CN_SEGMENTS, &replace_segment)
          removed = inner.gsub(CN_SEGMENTS, "")
          replaced == removed ? '' : replaced
        else
          ''
        end
      end
      self.meta_info['cn'].to_s.gsub(CN_SEGMENTS, &replace_segment).gsub(/\/+$/, '')
    end

  end

end
