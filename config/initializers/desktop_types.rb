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

# NOTE: All desktops must be stubbed in the spec
return if ENV['RACK_ENV'] == 'test'

# Periodically reload and verify the desktops
Thread.new do
  count = 0
  loop do
    models = SystemCommand.avail_desktops(user: ENV['USER'])
                          .tap(&:raise_unless_successful)
                          .stdout
                          .each_line.map do |line|
      data = line.split("\t")
      home = data[2].empty? ? nil : data[2]
      Desktop.new(name: data[0], summary: data[1], homepage: home)
    end

    models.each { |m| m.verify_desktop(user: ENV['USER']) }
    hash = models.map { |m| [m.name, m] }.to_h

    Desktop.instance_variable_set(:@cache, hash)
    DEFAULT_LOGGER.info "Finished #{'re' if count > 0 }loading the desktops"
    count += 1

    sleep FlightDesktopRestAPI.config.refresh_rate
  end
end

