class ::RSpec::Core::Ordering::Random
  # there are a lot of these in the RSpec specs that create noise
  HIDE_RANDOM_WARNINGS = true
end

require_relative './fixes/missing_constants'
require_relative './fixes/not_compatible'
require_relative './spec_helper_opal'
require 'support/matchers'
require 'rspec/support/spec/deprecation_helpers'
require 'opal/fixes/deprecation_helpers'
require 'opal/fixes/rspec_helpers'
require 'rspec/expectations/config'
require 'rspec/expectations/shared_examples'
require 'support/shared_examples'
