# The MIT License (MIT)
#
# Copyright (c) 2026 rick barrette
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


module RedmineQboCalendar
  module Patches
    # Saving this plugin's settings: appointments with a removed status are moved to the status chosen for
    # them on the settings page (settings[status_moves][removed key] = new key)
    module SettingsControllerPatch

      def plugin
        moves = params[:settings]&.delete(:status_moves) if request.post? && params[:id] == 'redmine_qbo_calendar'
        # The removed statuses' names, for the notice
        names = RedmineQboCalendar::AppointmentStatus.all.to_h { |s| [s.key, s.name] } if moves.present?
        super
        return if moves.blank?

        moved = RedmineQboCalendar::AppointmentStatus.move_appointments(moves.permit!.to_h, names: names)
        flash[:notice] = [flash[:notice], *moved.map { |m| l(:notice_appointments_moved, **m) }].compact.join(' ') if moved.any?
      end

    end
  end
end
