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
    module CalendarsControllerPatch

      def show
        log "show"

        # 1. Update or retrieve saved month/year from session before super runs
        if params[:year].present? && params[:month].present?
          session[:qbo_calendar_year]  = params[:year].to_i
          session[:qbo_calendar_month] = params[:month].to_i
        elsif session[:qbo_calendar_year].present? && session[:qbo_calendar_month].present?
          params[:year]  ||= session[:qbo_calendar_year]
          params[:month] ||= session[:qbo_calendar_month]
        end

        # 2. Call Redmine core CalendarsController#show
        super

        return unless @calendar

        # Grab whatever Redmine already loaded
        events = @calendar.instance_variable_get(:@events).dup

        log "events: #{events.inspect}"

        appointments = CustomerAppointment.visible(User.current)

        log "appointments: #{appointments.inspect}"

        # If we're inside a project, only show that project's appointments
        # if @project
        #   appointments = appointments.where(project_id: @project.id)
        # end

        # Only appointments visible in the displayed month
        # appointments = appointments.where(
        #   "(start_date BETWEEN :start AND :finish)
        #    OR
        #    (end_date BETWEEN :start AND :finish)
        #    OR
        #    (start_date <= :start AND end_date >= :finish)",
        #   start: @calendar.startdt.beginning_of_day,
        #   finish: @calendar.enddt.end_of_day
        # )

        events.concat(appointments)

        # Rebuild Redmine's internal event maps
        @calendar.events = events
      end

      private

      def log(msg)
        Rails.logger.info "[CalendarsControllerPatch] #{msg}"
      end

    end
  end
end