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

require 'spec_helper'

RSpec.describe '/sessions' do
  describe 'GET /sessions/:id' do
    let(:url_id) { raise NotImplementedError, 'the spec :id has not been set' }

    def make_request
      get "/sessions/#{url_id}"
    end

    context 'with a stubbed missing session' do
      let(:url_id) { 'missing' }

      before do
        allow(SystemCommand).to receive(:find_session).and_return(SystemCommand.new(code: 1))
        make_request
      end

      it 'returns 404' do
        expect(last_response).to be_not_found
      end
    end

    context 'with a stubbed existing session' do
      let(:subject) do
        Session.new(
          id: "11a8e4a1-9371-4b60-8d00-20441a4f2612",
          session_type: "gnome",
          ip: '10.1.0.1',
          hostname: 'example.com',
          port: 5956,
          password: '97InM80d'
        )
      end

      before do
        # NOTE: This stub is based on the raw output from the following:
        # flight desktop show <id> | cat
        #
        # All the sensitive values have been changed for security reasons
        # However the line spacing has been retained
        stubbed = SystemCommand.new(
          stderr: '', code: 0, stdout: <<~STDOUT
            Identity        #{subject.id}
            Type    #{subject.session_type}
            Host IP #{subject.ip}
            Hostname        #{subject.hostname}
            Port    #{subject.port}
            Display IGNORE_THIS_FIELD
            Password        #{subject.password}
          STDOUT
        )
        allow(SystemCommand).to receive(:find_session).and_return(stubbed)
        make_request
      end

      context 'when using a fuzzy id in the end point' do
        let(:url_id) { subject.id.split('-').first }

        it 'returns okay' do
          expect(last_response).to be_ok
        end

        it 'returns the subject as JSON' do
          expect(parse_last_response_body).to eq(subject.as_json)
        end
      end
    end
  end
end

