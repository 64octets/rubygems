##
# A semi-compatible DSL for the Bundler Gemfile and Isolate formats.

class Gem::RequestSet::GemDependencyAPI

  ##
  # The dependency groups created by #group in the dependency API file.

  attr_reader :dependency_groups

  ##
  # A set of gems that are loaded via the +:path+ option to #gem

  attr_reader :vendor_set # :nodoc:

  ##
  # The groups of gems to exclude from installation

  attr_accessor :without_groups

  ##
  # Creates a new GemDependencyAPI that will add dependencies to the
  # Gem::RequestSet +set+ based on the dependency API description in +path+.

  def initialize set, path
    @set = set
    @path = path

    @current_groups    = nil
    @default_sources   = true
    @dependency_groups = Hash.new { |h, group| h[group] = [] }
    @vendor_set        = @set.vendor_set
    @without_groups    = []
  end

  ##
  # Loads the gem dependency file

  def load
    instance_eval File.read(@path).untaint, @path, 1
  end

  ##
  # :category: Gem Dependencies DSL
  # :call-seq:
  #   gem(name)
  #   gem(name, *requirements)
  #   gem(name, *requirements, options)
  #
  # Specifies a gem dependency with the given +name+ and +requirements+.  You
  # may also supply +options+ following the +requirements+

  def gem name, *requirements
    options = requirements.pop if requirements.last.kind_of?(Hash)
    options ||= {}

    if directory = options.delete(:path) then
      @vendor_set.add_vendor_gem name, directory
    end

    g = options.delete :group
    all_groups  = g ? Array(g) : []

    groups = options.delete :groups
    all_groups |= groups if groups

    all_groups |= @current_groups if @current_groups

    all_groups.each do |group|
      gem_arguments = [name, *requirements]
      gem_arguments << options unless options.empty?
      @dependency_groups[group] << gem_arguments
    end

    return unless (all_groups & @without_groups).empty?

    @set.gem name, *requirements
  end

  ##
  # Returns the basename of the file the dependencies were loaded from

  def gem_deps_file # :nodoc:
    File.basename @path
  end

  ##
  # :category: Gem Dependencies DSL
  # Block form for placing a dependency in the given +groups+.

  def group *groups
    @current_groups = groups

    yield

  ensure
    @current_groups = nil
  end

  ##
  # :category: Gem Dependencies DSL

  def platform what
    if what == :ruby
      yield
    end
  end

  ##
  # :category: Gem Dependencies DSL

  alias :platforms :platform

  ##
  # :category: Gem Dependencies DSL
  # Restricts this gem dependencies file to the given ruby +version+.  The
  # +:engine+ options from Bundler are currently ignored.

  def ruby version, options = {}
    engine         = options[:engine]
    engine_version = options[:engine_version]

    raise ArgumentError,
          'you must specify engine_version along with the ruby engine' if
            engine and not engine_version

    unless RUBY_VERSION == version then
      message = "Your Ruby version is #{RUBY_VERSION}, " +
                "but your #{gem_deps_file} requires #{version}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine and engine != RUBY_ENGINE then
      message = "Your ruby engine is #{RUBY_ENGINE}, " +
                "but your #{gem_deps_file} requires #{engine}"

      raise Gem::RubyVersionMismatch, message
    end

    return true
  end

  ##
  # :category: Gem Dependencies DSL
  #
  # Sets +url+ as a source for gems for this dependency API.

  def source url
    Gem.sources.clear if @default_sources

    @default_sources = false

    Gem.sources << url
  end

  # TODO: remove this typo name at RubyGems 3.0

  Gem::RequestSet::DepedencyAPI = self # :nodoc:

end

