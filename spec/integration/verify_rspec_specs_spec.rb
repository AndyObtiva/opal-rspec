require 'spec_helper'
require 'rspec/opal_rspec_spec_loader'

RSpec.describe 'RSpec specs:' do

  def expect_results_to_be(expected_results)
    results = run_specs
    failures = results.json[:examples].select { |ex| ex[:status] == 'failed' }
    print_results(results) unless failures.empty?

    expect(results.json[:summary_line]).to eq(expected_results)
    expect(failures).to eq([])
    expect(results).to be_successful
  rescue
    print_results(results)
  end

  def print_results(results)
    puts "=========== Output of failed run ============"
    puts results.quoted_output
    puts "============================================="
  end

  def spec_glob
    ["rspec-#{short_name}/spec/**/*_spec.rb",]
  end

  context 'Core' do
    include Opal::RSpec::OpalRSpecSpecLoader
    let(:short_name) { 'core' }

    it 'runs correctly' do
      expect_results_to_be('801 examples, 0 failures, 139 pending')
    end
  end

  context 'Support' do
    include Opal::RSpec::OpalRSpecSpecLoader
    let(:short_name) { 'support' }

    it 'runs correctly' do
      expect_results_to_be('66 examples, 0 failures, 14 pending')
    end
  end

  context 'Expectations' do
    include Opal::RSpec::OpalRSpecSpecLoader
    let(:short_name) { 'expectations' }

    it 'runs correctly' do
      expect_results_to_be('65 examples, 0 failures, 13 pending')
    end
  end

end