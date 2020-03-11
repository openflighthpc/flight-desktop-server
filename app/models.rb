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

class Session < Hashie::Trash
  include Hashie::Extensions::Dash::Coercion

  # NOTE: The flight desktop command generates a UUID for each session, however
  # it also allows accepts shortened versions. This means their is some "fuzziness"
  # in the ID.
  #
  # Revists as necessary, we may want to disable this
  def self.find_by_fuzzy_id(fuzzy_id, user:)
    cmd = SystemCommand.find_session(fuzzy_id, user: user)
    return nil unless cmd.code == 0
    data = cmd.stdout.split("\n").each_with_object({}) do |line, memo|
      parts = line.split(/\s+/)
      value = parts.pop
      key = case parts.join(' ')
      when 'Identity'
        :id
      when 'Host IP'
        :ip
      when 'Hostname'
        :hostname
      when 'Port'
        :port
      when 'Password'
        :password
      when 'Type'
        :session_type
      else
        next # Ignore any extraneous keys
      end
      memo[key] = value
    end
    new(**data)
  end

  def self.start_session(desktop, user:)
    cmd = SystemCommand.start_session(desktop, user: user)
    if cmd.success?
      # noop
    else
      raise UnknownDesktop
    end
  end

  property :id
  property :session_type
  property :ip
  property :hostname
  property :port, coerce: String
  property :password
end

