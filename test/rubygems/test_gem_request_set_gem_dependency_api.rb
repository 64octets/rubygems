require 'rubygems/test_case'
require 'rubygems/request_set'

class TestGemRequestSetGemDependencyAPI < Gem::TestCase

  def setup
    super

    @GDA = Gem::RequestSet::GemDependencyAPI

    @set = Gem::RequestSet.new

    @vendor_set = Gem::DependencyResolver::VendorSet.new

    @gda = @GDA.new @set, 'gem.deps.rb'
    @gda.instance_variable_set :@vendor_set, @vendor_set
  end

  def with_engine_version name, version
    engine               = RUBY_ENGINE if Object.const_defined? :RUBY_ENGINE
    engine_version_const = "#{engine.upcase}_VERSION" if engine
    engine_version       = Object.const_get engine_version_const if engine

    Object.send :remove_const, :RUBY_ENGINE         if engine
    Object.send :remove_const, engine_version_const if engine_version

    Object.const_set :RUBY_ENGINE,         name    if name
    Object.const_set engine_version_const, version if version

    yield

  ensure
    Object.send :remove_const, :RUBY_ENGINE         if name
    Object.send :remove_const, engine_version_const if version

    Object.const_set :RUBY_ENGINE,         engine         if engine
    Object.const_set engine_version_const, engine_version if engine_version
  end

  def test_gem
    @gda.gem 'a'

    assert_equal [dep('a')], @set.dependencies
  end

  def test_gem_group
    @gda.gem 'a', :group => :test

    expected = {
      :test => [['a']],
    }

    assert_equal expected, @gda.dependency_groups

    assert_equal [dep('a')], @set.dependencies
  end

  def test_gem_group_without
    @gda.without_groups << :test

    @gda.gem 'a', :group => :test

    expected = {
      :test => [['a']],
    }

    assert_equal expected, @gda.dependency_groups

    assert_empty @set.dependencies
  end

  def test_gem_groups
    @gda.gem 'a', :groups => [:test, :development]

    expected = {
      :development => [['a']],
      :test        => [['a']],
    }

    assert_equal expected, @gda.dependency_groups

    assert_equal [dep('a')], @set.dependencies
  end

  def test_gem_path
    name, version, directory = vendor_gem

    @gda.gem name, :path => directory

    assert_equal [dep(name)], @set.dependencies

    loaded = @vendor_set.load_spec(name, version, Gem::Platform::RUBY, nil)

    assert_equal "#{name}-#{version}", loaded.full_name
  end

  def test_gem_requirement
    @gda.gem 'a', '~> 1.0'

    assert_equal [dep('a', '~> 1.0')], @set.dependencies
  end

  def test_gem_requirements
    @gda.gem 'b', '~> 1.0', '>= 1.0.2'

    assert_equal [dep('b', '~> 1.0', '>= 1.0.2')], @set.dependencies
  end

  def test_gem_requirements_options
    @gda.gem 'c', :git => 'https://example/c.git'

    assert_equal [dep('c')], @set.dependencies
  end

  def test_gem_deps_file
    assert_equal 'gem.deps.rb', @gda.gem_deps_file

    gda = @GDA.new @set, 'foo/Gemfile'

    assert_equal 'Gemfile', gda.gem_deps_file
  end

  def test_group
    @gda.group :test do
      @gda.gem 'a'
    end

    assert_equal [['a']], @gda.dependency_groups[:test]

    assert_equal [dep('a')], @set.dependencies
  end

  def test_group_multiple
    @gda.group :a do
      @gda.gem 'a', :group => :b, :groups => [:c, :d]
    end

    assert_equal [['a']], @gda.dependency_groups[:a]
    assert_equal [['a']], @gda.dependency_groups[:b]
    assert_equal [['a']], @gda.dependency_groups[:c]
    assert_equal [['a']], @gda.dependency_groups[:d]

    assert_equal [dep('a')], @set.dependencies
  end

  def test_load
    Tempfile.open 'gem.deps.rb' do |io|
      io.write <<-GEM_DEPS
gem 'a'

group :test do
  gem 'b'
end
      GEM_DEPS
      io.flush

      gda = @GDA.new @set, io.path

      gda.load

      expected = {
        :test => [['b']],
      }

      assert_equal expected, gda.dependency_groups

      assert_equal [dep('a'), dep('b')], @set.dependencies
    end
  end

  def test_name_typo
    assert_same @GDA, Gem::RequestSet::DepedencyAPI
  end

  def test_platform_mswin
    @gda.platform :mswin do
      @gda.gem 'a'
    end

    assert_empty @set.dependencies
  end

  def test_platform_ruby
    @gda.platform :ruby do
      @gda.gem 'a'
    end

    assert_equal [dep('a')], @set.dependencies
  end

  def test_platforms
    @gda.platforms :ruby do
      @gda.gem 'a'
    end

    assert_equal [dep('a')], @set.dependencies
  end

  def test_ruby
    assert @gda.ruby RUBY_VERSION
  end

  def test_ruby_engine
    with_engine_version 'jruby', '1.7.6' do
      assert @gda.ruby RUBY_VERSION,
               :engine => 'jruby', :engine_version => '1.7.6'

    end
  end

  def test_ruby_engine_mismatch_engine
    with_engine_version 'ruby', '2.0.0' do
      e = assert_raises Gem::RubyVersionMismatch do
        @gda.ruby RUBY_VERSION, :engine => 'jruby', :engine_version => '1.7.4'
      end

      assert_equal 'Your ruby engine is ruby, but your gem.deps.rb requires jruby',
                   e.message
    end
  end

  def test_ruby_engine_no_engine_version
    e = assert_raises ArgumentError do
      @gda.ruby RUBY_VERSION, :engine => 'jruby'
    end

    assert_equal 'you must specify engine_version along with the ruby engine',
                 e.message
  end

  def test_ruby_mismatch
    e = assert_raises Gem::RubyVersionMismatch do
      @gda.ruby '1.8.0'
    end

    assert_equal "Your Ruby version is #{RUBY_VERSION}, but your gem.deps.rb requires 1.8.0", e.message
  end

  def test_source
    sources = Gem.sources

    @gda.source 'http://first.example'

    assert_equal %w[http://first.example], Gem.sources

    assert_same sources, Gem.sources

    @gda.source 'http://second.example'

    assert_equal %w[http://first.example http://second.example], Gem.sources
  end

end

