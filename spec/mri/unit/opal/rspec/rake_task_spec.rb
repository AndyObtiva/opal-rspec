require 'rspec'
require 'opal/rspec/rake_task'
require 'rack'
require_relative 'temp_dir_helper'

describe Opal::RSpec::RakeTask do
  include_context :temp_dir
  let(:captured_opal_server) { {} }
  let(:runner) { :phantom }
  before { ENV['RUNNER'] = runner.to_s }

  RSpec::Matchers.define :invoke_runner do |expected|
    expected_value = [expected]
    match { expect(invoked_runners).to eq(expected_value) }
    failure_message { {expected: expected_value, got: invoked_runners}.inspect }
  end

  RSpec::Matchers.define :enable_arity_checking do
    match do
      Opal::Config.arity_check_enabled == true
    end
  end

  RSpec::Matchers.define :require_opal_specs do |matcher|
    def actual
      captured_opal_server[:sprockets].cached.get_opal_spec_requires
    end

    match do
      matcher.matches? actual
    end

    failure_message do
      matcher.failure_message
    end

    failure_message_when_negated do
      matcher.failure_message_when_negated
    end
  end

  RSpec::Matchers.define :append_opal_path do |expected_path|
    def actual
      captured_opal_server[:sprockets].paths
    end

    abs_expected = lambda { File.expand_path(expected_path) }

    match do
      actual.include? abs_expected.call
    end

    failure_message do
      "Expected paths #{actual} to include #{abs_expected.call}"
    end

    failure_message_when_negated do
      "Expected paths #{actual} to not include #{abs_expected.call}"
    end
  end

  before do
    if Rake::Task.tasks.map { |t| t.name }.include?(task_name.to_s) # Don't want prior examples to mess up state
      task = Rake::Task[task_name]
      task.clear
      task.reenable
    end
    allow(Rack::Server).to receive(:start) do |config|
      # don't want to actually run specs
    end
    thread_double = instance_double Thread
    allow(thread_double).to receive :kill
    allow(Thread).to receive(:new) do |&block| # real threads would complicate specs
      block.call
      thread_double
    end

    dummy_launch = -> (runner_name, sprockets, main, &config_block) {
      config_block.call
      captured_opal_server[:sprockets] = sprockets
      captured_opal_server[:main] = main
      invoked_runners << runner_name
      nil
    }

    allow(task_definition).to receive(:launch_phantom) do |*args, &block|
      dummy_launch.call(:phantom, *args, &block)
    end

    allow(task_definition).to receive(:launch_node) do |*args, &block|
      dummy_launch.call(:node, *args, &block)
    end
  end

  after { raise "did not run" if invoked_runners.empty? if expected_to_run }

  let(:invoked_runners) { [] }
  let(:task_name) { :foobar }
  let(:expected_to_run) { true }

  subject do
    task = task_definition
    Rake::Task[task_name].invoke
    task
  end

  context 'default' do
    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name)
    end

    before do
      create_dummy_spec_files 'spec/something/dummy_spec.rb'
    end

    around do |example|
      expect(runner).to eq(:phantom)
      # in case we're running on travis, etc.
      current_env_runner = ENV['RUNNER']
      ENV['RUNNER'] = nil
      example.run
      ENV['RUNNER'] = current_env_runner
    end

    it { is_expected.to have_attributes pattern: nil }
    it { is_expected.to append_opal_path 'spec' }
    it { is_expected.to require_opal_specs eq ['something/dummy_spec'] }
    it { is_expected.to invoke_runner :phantom }
  end

  context 'Opal 0.10' do
    before do
      stub_const('Opal::VERSION', '0.10.0.dev')
      create_dummy_spec_files 'spec/something/dummy_spec.rb'
    end

    around do |example|
      # in case we're running on travis, etc.
      current_env_runner = ENV['RUNNER']
      ENV['RUNNER'] = nil
      example.run
      ENV['RUNNER'] = current_env_runner
    end

    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name) do |_, task|
        task.arity_checking = arity_setting if arity_setting
      end
    end

    context 'no setting' do
      let(:arity_setting) { nil }

      it { is_expected.to enable_arity_checking }
      it { is_expected.to append_opal_path 'spec' }
      it { is_expected.to require_opal_specs eq ['something/dummy_spec'] }
      it { is_expected.to invoke_runner :phantom }
    end

    context 'enabled' do
      let(:arity_setting) { :enabled }

      it { is_expected.to enable_arity_checking }
      it { is_expected.to append_opal_path 'spec' }
      it { is_expected.to require_opal_specs eq ['something/dummy_spec'] }
      it { is_expected.to invoke_runner :phantom }
    end

    context 'disabled' do
      let(:arity_setting) { :disabled }

      it { is_expected.to_not enable_arity_checking }
      it { is_expected.to append_opal_path 'spec' }
      it { is_expected.to require_opal_specs eq ['something/dummy_spec'] }
      it { is_expected.to invoke_runner :phantom }
    end
  end

  context 'explicit runner' do
    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name)
    end

    before do
      ENV['RUNNER'] = nil
      create_dummy_spec_files 'spec/something/dummy_spec.rb'
    end

    RSpec.shared_context :explicit do |expected_runner|
      it { is_expected.to have_attributes pattern: nil }
      it { is_expected.to append_opal_path 'spec' }
      it { is_expected.to require_opal_specs eq ['something/dummy_spec'] }
      it { is_expected.to invoke_runner expected_runner }
    end

    TEST_RUNNERS = [:phantom, :node]

    context 'ENV' do
      TEST_RUNNERS.each do |runner|
        context runner do
          let(:runner) { runner }
          before { ENV['RUNNER'] = runner.to_s }

          include_context :explicit, runner
        end
      end
    end

    context 'Rake task' do
      TEST_RUNNERS.each do |runner|
        context runner do
          before do
            task_definition.runner = runner
          end

          include_context :explicit, runner
        end
      end
    end
  end

  context 'pattern' do
    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name) do |_, task|
        task.pattern = 'spec/other/**/*_spec.rb'
      end
    end

    before do
      create_dummy_spec_files 'spec/other/dummy_spec.rb'
    end

    it { is_expected.to have_attributes pattern: 'spec/other/**/*_spec.rb' }
    it { is_expected.to append_opal_path 'spec' }
    it { is_expected.to require_opal_specs eq ['other/dummy_spec'] }
  end

  context 'default path' do
    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name) do |server, task|
        task.pattern = 'spec/other/**/*_spec.rb'
        task.default_path = 'spec/other'
      end
    end

    before do
      create_dummy_spec_files 'spec/other/dummy_spec.rb'
    end

    it { is_expected.to have_attributes pattern: 'spec/other/**/*_spec.rb' }
    it { is_expected.to append_opal_path 'spec/other' }
    it { is_expected.to_not append_opal_path 'spec' }
    it { is_expected.to require_opal_specs eq ['dummy_spec'] }
  end

  context 'files' do
    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name) do |_, task|
        task.files = FileList['spec/other/**/*_spec.rb']
      end
    end

    before do
      create_dummy_spec_files 'spec/other/dummy_spec.rb'
    end

    it { is_expected.to have_attributes files: FileList['spec/other/**/*_spec.rb'] }
    it { is_expected.to append_opal_path 'spec' }
    it { is_expected.to require_opal_specs eq ['other/dummy_spec'] }
  end

  context 'pattern and files' do
    let(:expected_to_run) { false }

    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name) do |_, task|
        task.files = FileList['spec/other/**/*_spec.rb', 'util/**/*.rb']
        task.pattern = 'spec/opal/**/*hooks_spec.rb'
      end
    end

    subject do
      lambda {
        task = task_definition
        Rake::Task[task_name].invoke
        task
      }
    end

    it { is_expected.to raise_exception 'Cannot supply both a pattern and files!' }
  end

  context 'custom timeout value' do
    let(:task_definition) do
      Opal::RSpec::RakeTask.new(task_name) do |server, task|
        task.timeout = 40000
      end
    end

    before do
      create_dummy_spec_files 'spec/something/dummy_spec.rb'
    end

    around do |example|
      # in case we're running on travis, etc.
      current_env_runner = ENV['RUNNER']
      ENV['RUNNER'] = nil
      example.run
      ENV['RUNNER'] = current_env_runner
    end

    it { is_expected.to have_attributes pattern: nil }
    it { is_expected.to append_opal_path 'spec' }
    it { is_expected.to require_opal_specs eq ['something/dummy_spec'] }
    it { is_expected.to invoke_runner :phantom }
    it 'has timeout set' do
      expect(subject.timeout).to eq(40000)
    end
  end
end
