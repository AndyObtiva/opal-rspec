require 'opal'
require 'opal-rspec'

# make sure should and expect syntax are both loaded
RSpec::Expectations::Syntax.enable_should
RSpec::Expectations::Syntax.enable_expect

# opal doesnt yet support module_exec for defining methods in modules properly
module RSpec::Matchers
  alias_method :expect, :expect
end

rspec_config = RSpec.configuration

# mock frameworks currently broken, so skip for now
# UPDATE: is this fixed by module.new fix?
def rspec_config.configure_mock_framework
  nil
end

# Module#include should also include constants (as should class subclassing)
RSpec::Core::ExampleGroup::AllHookMemoizedHash = RSpec::Core::MemoizedHelpers::AllHookMemoizedHash

# Rspec makes examples thread safe....
class Thread
  def self.current
    @current ||= self.new
  end

  def initialize
    @hash = {}
  end

  def [](key)
    @hash[key]
  end

  def []=(key, val)
    @hash[key] = val
  end
end

# bad.. something is going wrong inside hooks - so set hooks to empty, for now
# or is it a problem with Array.public_instance_methods(false) adding all array
# methods to this class and thus breaking things like `self.class.new`
class RSpec::Core::Hooks::HookCollection
  def for(a)
    RSpec::Core::Hooks::HookCollection.new.with(a)
  end
end

class RSpec::Core::Hooks::AroundHookCollection
  def for(a)
    RSpec::Core::Hooks::AroundHookCollection.new.with(a)
  end
end

# something wrong with mocks?
class RSpec::Core::ExampleGroup
  def teardown_mocks_for_rspec
    nil
  end

  alias_method :setup_mocks_for_rspec, :teardown_mocks_for_rspec
  alias_method :verify_mocks_for_rspec, :teardown_mocks_for_rspec
end

describe "Adam" do
  it "should eat" do
    1.should == 1
  end
end

describe "Benjamin" do
  it "likes cream in his tea" do
    1.should == 3
  end

  it "should eat bacon" do
    "bacon".should be_a_kind_of(String)
  end
end

class OpalRSpecRunner
  def initialize(options = {}, configuration = RSpec::configuration, world = RSpec::world)
    @options        = options
    @configuration  = configuration
    @world          = world
  end

  def run(err, out)
    # load specs here!
    @configuration.error_stream = err
    @configuration.output_stream ||= out
    #@options.configure(@configuration)
    # @configuration.load_spec_files
    # @world.announce_filters

    puts @world.example_count
    # @configuration.reporter.report(@world.example_count) do |reporter|
      begin
        # @configuration.run_hook(:before, :suite)
        # @world.ordered_example_groups.map {|g| g.run(reporter) }.all? ? 0 : @configuration.failure_exit_code
        @world.example_groups.map { |g| g.run(reporter) }

      ensure
        #@configuration.run_hook(:after, :suite)
      end
    # end
  end

  def reporter
    return @reporter if @reporter

    @reporter = BasicObject.new
    def @reporter.method_missing(*args); Kernel.p args; end
    def @reporter.example_failed(example)
      Kernel.p([:example_failed])
      #Kernel.puts example.inspect
      exception = example.metadata[:execution_result][:exception]
      Kernel.puts exception
      `console.log(exception.stack)`
    end

    def @reporter.example_started(example)
      Kernel.puts "starting: #{example.description}"
    end

    @reporter
  end
end

OpalRSpecRunner.new.run($stdout, $stdout)
