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

# Loads the available desktops from either the CLI or the environment
desktops =  if Figaro.env.desktop_types
              Figaro.env.desktop_types.split(',')
            else
              cmd = SystemCommand.avail_desktops(user: Figaro.env.USER!)
              cmd.raise_unless_successful
              cmd.stdout.each_line.map { |l| l.split(' ').first }
            end
models = desktops.map { |n| Desktop.new(name: n) }

# Verifies the desktops for the list command
Thread.new do
  next if Figaro.env.RACK_ENV! == 'test'
  loop do
    models.each { |m| m.verify_desktop(user: Figaro.env.USER!) }
    sleep Figaro.env.refresh_rate!.to_i
  end
end

Desktop.instance_variable_set(:"@index", models)

