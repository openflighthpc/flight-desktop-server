# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of FlightDesktopServer.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# FlightDesktopServer is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with FlightDesktopServer. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on FlightDesktopServer, please visit:
# https://github.com/openflighthpc/flight-desktop-server
#===============================================================================

ENV['RACK_ENV'] = 'test'

require 'rake'
load File.expand_path('../Rakefile', __dir__)
Rake::Task[:require].invoke

module RSpecSinatraMixin
  include Rack::Test::Methods

  def app()
    Sinatra::Application.new
  end
end

module SharedSpecContext
  extend RSpec::SharedContext

  let(:exit_213_stub) { SystemCommand.new(code: 213) }
  let(:exit_0_stub) { SystemCommand.new(code: 0) }

  let(:username) { 'default-test-user' }
  let(:password) { 'default-test-password' }

  let(:cache_dir) { "/home/#{username}/.cache" }

  def define_desktop(name, verified: true)
    Desktop.new(name: name.to_s, verified: verified).tap do |model|
      Desktop.instance_variable_get(:@cache)[model.name] = model
    end
  end

  around do |example|
    Desktop.instance_variable_set(:@cache, {})
    example.call
    Desktop.instance_variable_set(:@cache, nil)
  end
end

RSpec.configure do |c|
	# Include the Sinatra helps into the application
	c.include RSpecSinatraMixin

  # Include the username and password
  c.include SharedSpecContext

  def parse_last_request_body
    json = JSON.parse(last_request.body)
    if json.is_a?(Array)
      json.map { |x| Hashie::Mash.new(x) }
    else
      Hashie::Mash.new(json)
    end
  end

  def parse_last_response_body
    json = JSON.parse(last_response.body)
    if json.is_a?(Array)
      json.map { |x| Hashie::Mash.new(x) }
    else
      Hashie::Mash.new(json)
    end
  end

  def last_error
    last_request.env['sinatra.error']
  end

  def standard_get_headers
    header 'Authorization', "Basic #{Base64.encode64("#{username}:#{password}")}"
  end

  def standard_post_headers
    standard_get_headers
    header 'Content-Type', 'application/json'
  end

  c.around { |e| FakeFS.with { e.call } }

  c.before do
    # Disable RPAM from running in the spec. This way users don't need configuring
    # It will always return authenticated unless otherwise stubbed
    allow(PamAuth).to receive(:valid?).and_return(true)

    # Disable the SystemCommand::Builder from creating commands
    # This forces all system commands to be mocked
    allow(SystemCommand::Builder).to receive(:new).and_wrap_original do |_, *a|
      raise NotImplementedError, <<~ERROR.squish
        Running system commands is not supported in the spec. The following
        needs to be stubbed: '#{a.first}'
      ERROR
    end

    # Always allow the SystemCommands for the cache directory as they will
    # likely always succeed [unless something terrible happens]
    allow(SystemCommand).to receive(:echo_cache_dir).and_wrap_original do
      SystemCommand.new(stderr: '', code: 0, stdout: "#{cache_dir}\n")
    end
  end
end

