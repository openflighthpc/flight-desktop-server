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
  subject { raise NotImplementedError, 'the spec has not defined its subject' }
  let(:url_id) { raise NotImplementedError, 'the spec :id has not been set' }

  let(:exit_1_stub) { SystemCommand.new(code: 1) }
  let(:exit_0_stub) { SystemCommand.new(code: 0) }

  shared_examples 'sessions error when missing' do
    context 'with a stubbed missing session' do
      let(:url_id) { 'missing' }

      before do
        allow(SystemCommand).to receive(:find_session).and_return(exit_1_stub)
        make_request
      end

      it 'returns 404' do
        expect(last_response).to be_not_found
      end
    end
  end

  describe 'GET /sessions/:id' do
    def make_request
      get "/sessions/#{url_id}"
    end

    include_examples 'sessions error when missing'

    context 'with a stubbed existing session' do
      subject do
        Session.new(
          id: "11a8e4a1-9371-4b60-8d00-20441a4f2612",
          session_type: "gnome",
          ip: '10.1.0.1',
          hostname: 'example.com',
          port: 5956,
          password: '97InM80d'
        )
      end

      let(:successful_find_stub) do
        SystemCommand.new(
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
      end

      before do
        allow(SystemCommand).to receive(:find_session).and_return(successful_find_stub)
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

  describe 'POST /sessions' do
    let(:desktop) { raise NotImplementedError, 'the spec :desktop has not been set' }

    let(:successful_create_stub) do
      SystemCommand.new(
        code: 0, stderr: '',
        stdout: <<~STDOUT
          Starting a '#{subject.session_type}' desktop session:

             > ✅ Starting session

          A '#{subject.session_type}' desktop session has been started.
          Identity        #{subject.id}
          Type    #{subject.session_type}
          Host IP #{subject.ip}
          Hostname        #{subject.hostname}
          Port    #{subject.port}
          Display IGNORE_THIS_FIELD
          Password        #{subject.password}
        STDOUT
      )
    end

    let(:unknown_create_stub) do
      SystemCommand.new(
        code: 1, stdout: '', stderr: "flight desktop: unknown desktop type: #{desktop}"
      )
    end

    let(:unverified_create_stub) do
      SystemCommand.new(
        code: 1, stdout: '', stderr: "flight desktop: Desktop type '#{desktop}' has not been verified"
      )
    end

    def make_request
      standard_headers
      post '/sessions', { desktop: desktop }.to_json
    end

    context 'when the request sends a missing desktop' do
      let(:desktop) { 'missing' }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unknown_create_stub)
        make_request
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end

      it 'returns Unknown Desktop' do
        expect(parse_last_response_body.errors.first.code).to eq('Unknown Desktop')
      end
    end

    context 'when the request does not send a desktop' do
      before do
        standard_headers
        post '/sessions'
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end
    end

    context 'when creating a verified desktop session' do
      subject do
        Session.new(
          id: '3335bb08-8d91-40fd-a973-da05bdbf3636',
          session_type: 'definitely-a-verified-desktop-type',
          ip: '10.1.0.2',
          hostname: 'example.com',
          port: 5905,
          password: 'WakofEb6'
        )
      end

      let(:desktop) { subject.session_type }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(successful_create_stub)
        make_request
      end

      it 'returns 201' do
        expect(last_response).to be_created
      end

      it 'returns the subject as JSON' do
        expect(parse_last_response_body).to eq(subject.as_json)
      end
    end

    context 'when creating a unverified desktop' do
      let(:desktop) { 'unverified' }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
      end

      it 'attempts to prepare the desktop' do
        expect(SystemCommand).to receive(:prepare_desktop).with(desktop, anything)
        make_request
      end
    end

    context 'when verifying a desktop fails' do
      let(:desktop) { 'unverified' }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
        expect(SystemCommand).to receive(:prepare_desktop).and_return(exit_1_stub)

        make_request
      end

      it 'returns 400' do
        expect(last_response).to be_bad_request
      end

      it 'returns Desktop Not Prepared' do
        expect(parse_last_response_body.errors.first.code).to eq('Desktop Not Prepared')
      end
    end

    context 'when verifing a desktop succeeds but the create otherwise fails' do
      let(:desktop) { 'unverified' }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(unverified_create_stub)
        expect(SystemCommand).to receive(:prepare_desktop).and_return(exit_0_stub)

        make_request
      end

      it 'returns 500' do
        expect(last_response.status).to be(500)
      end
    end

    context 'when verifing a desktop command succeeds and the retry also succeeds' do
      subject do
        Session.new(
          id: '9633d854-1790-43b2-bf06-f6dc46bb4859',
          session_type: 'unverified',
          ip: '10.1.0.3',
          hostname: 'example.com',
          port: 5906,
          password: 'ca77d490'
        )
      end

      let(:desktop) { subject.session_type }

      before do
        allow(SystemCommand).to receive(:start_session).and_return(
          unverified_create_stub, successful_create_stub
        )
        expect(SystemCommand).to receive(:prepare_desktop).and_return(exit_0_stub)

        make_request
      end

      it 'returns 201' do
        expect(last_response).to be_created
      end

      it 'returns the subject as JSON' do
        expect(parse_last_response_body).to eq(subject.as_json)
      end
    end
  end

  describe 'DELETE /session/:id' do
    def make_request
      delete "/sessions/#{url_id}"
    end

    include_examples 'sessions error when missing'
  end
end

