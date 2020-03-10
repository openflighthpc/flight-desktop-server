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

class HttpError < StandardError
  class << self
    attr_writer :default_http_status, :code
  end

  def self.code
    @code ||= self.name.titleize
  end

  def self.default_http_status
    @default_http_status ||= 500
  end

  def initialize(message=nil, http_status: nil)
    @http_status = http_status
    super(message)
  end

  def http_status
    @http_status || self.class.default_http_status
  end

  def as_json(_options={})
    {
      status: self.http_status.to_s,
      code: self.class.code,
    }.tap { |h| h[:details] = message if message }
  end
end

class InternalServerError < HttpError
  def initialize(message = nil)
  end
end

