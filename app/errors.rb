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

class HttpError < StandardError
  class << self
    attr_writer :default_http_status, :code
  end

  def self.code
    @code ||= self.name.titleize
  end

  def self.default_http_status
    @default_http_status ||= if self == HttpError
                               500
                             else
                               superclass.default_http_status
                             end
  end

  attr_reader :detail

  def initialize(message = nil, detail: nil, http_status: nil)
    @http_status = http_status
    @detail = detail
    super([message, detail].join("\n"))
  end

  def http_status
    @http_status || self.class.default_http_status
  end

  def as_json(_options={})
    {
      status: self.http_status.to_s,
      code: self.class.code,
    }.tap { |h| h[:detail] = detail if detail }
  end
end

class BadRequest < HttpError
  self.default_http_status = 400
end

class DesktopNotPrepared < BadRequest; end

class NotFound < HttpError
  self.default_http_status = 404

  def initialize(*a, type: nil, id: nil, detail: nil, **opts)
    if type && id
      detail ||= "Could not find '#{type}': #{id}"
    end
    super(*a, detail: detail, **opts)
  end
end

class UserNotFound < HttpError
  self.default_http_status = 404
end

class InternalServerError < HttpError
end

class UnexpectedError < InternalServerError; end

class UnsupportedMediaType < HttpError
  self.default_http_status = 415
end

class Unauthorized < HttpError
  self.default_http_status = 401
end

class Forbidden < HttpError
  self.default_http_status = 403
end

class RootForbidden < Forbidden; end

