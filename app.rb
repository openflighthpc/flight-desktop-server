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

require 'sinatra'
require 'sinatra/namespace'

set :show_exceptions, :after_handler

# Converts HttpError objects into their JSON representation. Each object already
# sets the response code
error(HttpError) do
  { errors: [env['sinatra.error']] }.to_json
end

# Catches all other errors and returns a generic Internal Server Error
error(StandardError) do
  { errors: [InternalServerError.new] }.to_json
end

# Sets the response Content-Type
before do
  content_type 'application/json'
end

# Checks the request Content-Type is application/json where appropriate
# Saves the input JSON as if it was a form input
# Adapted from:
# https://raw.githubusercontent.com/rack/rack-contrib/master/lib/rack/contrib/post_body_content_type_parser.rb
before do
  next if ['GET', 'DELETE'].include? env['REQUEST_METHOD']
  if env['CONTENT_TYPE'] == 'application/json'
    begin
      io = env['rack.input']
      body = io.read
      io.rewind
      json = body.empty? ? {} : JSON.parse(body, create_additions: false)
      raise BadRequest.new(detail: 'the body must be a JSON hash') unless json.is_a?(Hash)
      json.each { |k, v| params[k] ||= v }
    rescue JSON::ParserError
      raise BadRequest.new(detail: 'failed to parse body as JSON')
    end
  else
    raise UnsupportedMediaType
  end
end

helpers do
  def current_user
    nil
  end
end

namespace '/sessions' do
  helpers do
    def desktop_param
      params[:desktop].tap do |d|
        next if d
        raise BadRequest.new(detail: 'the "desktop" attribute is required by this request')
      end
    end
  end

  get do
    Session.index(user: current_user).to_json
  end

  post do
    status 201
    Session.start_session(desktop_param, user: current_user).to_json
  end

  namespace('/:id') do
    helpers do
      def id_param
        params[:id]
      end

      def current_session
        Session.find_by_fuzzy_id(id_param, user: current_user).tap do |s|
          next if s
          raise NotFound.new(type: 'session', id: id_param)
        end
      end
    end

    get do
      current_session.to_json
    end

    get '/screenshot' do
      current_session
    end

    delete do
      status 204
      current_session.kill(user: current_user)
    end
  end
end

