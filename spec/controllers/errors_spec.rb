# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of FlightDesktopRestAPI.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# FlightDesktopRestAPI is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with FlightDesktopRestAPI. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on FlightDesktopRestAPI, please visit:
# https://github.com/openflighthpc/flight-desktop-restapi
#===============================================================================

require 'spec_helper'

# Demo Route for error mocking
module StubError
  def self.call; end

  def self.stub(ex)
    ex.allow(self).to ex.receive(:call).and_wrap_original { yield if block_given? }
  end
end

Sinatra::Application.get('/test-error-handling') do
  StubError.call
end

Sinatra::Application.post('/test-error-handling') do
  StubError.call
end

RSpec.describe 'Error Handling' do
  shared_examples 'returns 401' do
    it 'returns 401' do
      get '/test-error-handling'
      expect(last_response).to be_unauthorized
    end
  end

  context 'with missing credentials' do
    include_examples 'returns 401'
  end

  context 'with a non Basic authorization scheme' do
    before do
      header 'Authorization', "Bearer bearer-tokens-are-not-supported"
    end

    include_examples 'returns 401'
  end

  context 'with missing base64 encoding' do
    before do
      header 'Authorization', "Basic"
    end

    include_examples 'returns 401'
  end

  context 'with junk credentials' do
    before do
      header 'Authorization', "Basic anVuaw=="
    end

    include_examples 'returns 401'
  end

  context 'with invalid credentials' do
    before do
      # allow(PamAuth).to receive(:valid?).and_return(false)
      standard_get_headers
    end

    include_examples 'returns 401'
  end

  context 'with valid root crendentials' do
    let(:username) { 'root' }

    before do
      standard_get_headers
      get '/test-error-handling'
    end

    it 'returns 403' do
      expect(last_response).to be_forbidden
    end
  end

  context 'with invalid root crendentials' do
    let(:username) { 'root' }

    before do
      standard_get_headers
      # allow(PamAuth).to receive(:valid?).and_return(true)
      get '/test-error-handling'
    end

    it 'returns 403' do
      expect(last_response).to be_forbidden
    end
  end

  describe 'GET' do
    def get_test_error_page
      standard_get_headers
      get '/test-error-handling'
    end

    def expect_internal_server_error
      error = parse_last_response_body.errors.first
      expect(error.status).to eq(last_response.status.to_s)
      expect(error.status).to eq('500')
      expect(error.keys).not_to include('details')
      expect(last_response.content_type).to eq('application/json')
    end

    it 'handles internal server errors' do
      StubError.stub(self) { raise InternalServerError }
      get_test_error_page
      expect_internal_server_error
    end

    it 'handles unexpected errors' do
      StubError.stub(self) { raise StandardError }
      get_test_error_page
      expect_internal_server_error
    end

    it 'handles User Not Found' do
      StubError.stub(self) { raise UserNotFound }
      get_test_error_page
      error = parse_last_response_body.errors.first
      expect(error.code).to eq('User Not Found')
      expect(error.status).to eq(last_response.status.to_s)
      expect(error.status).to eq('404')
    end
  end

  describe 'POST' do
    context 'when Content-Type is set to "application/json"' do
      before do
        standard_post_headers
        post '/test-error-handling', ''
      end

      it 'returns 200' do
        expect(last_response).to be_ok
      end

      it 'sets the response Content-Type' do
        expect(last_response.content_type).to eq('application/json')
      end
    end

    context 'when Content-Type has not been set' do
      before do
        standard_get_headers
        post '/test-error-handling'
      end

      it 'returns 415' do
        expect(last_response.status).to be(415)
      end

      it 'sets the response Content-Type' do
        expect(last_response.content_type).to eq('application/json')
      end
    end

    context 'when the body is invalid json' do
      before do
        standard_post_headers
        post '/test-error-handling', '}{'
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end
    end

    context 'when the body is a JSON array' do
      before do
        standard_post_headers
        post '/test-error-handling', '[]'
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end
    end
  end
end

