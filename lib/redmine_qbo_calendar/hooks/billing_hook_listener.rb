#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module RedmineQboCalendar
  module Hooks

    # Hooks for redmine_qbo_billing
    class BillingHookListener < Redmine::Hook::Listener

      # "Create issues" opened from an appointment (?appointment_id=): the issues get the appointment's dates,
      # technician, vehicle and project, and the page returns to the appointment
      def qbo_billing_issue_defaults(context = {})
        appointment_id = context.dig(:params, :appointment_id)
        return nil if appointment_id.blank?
        return nil unless User.current.allowed_to?(:view_customer_appointments, nil, global: true)

        appointment = CustomerAppointment.find_by(id: appointment_id)
        estimate = context[:estimate]
        return nil unless appointment && estimate && appointment.estimate_id.to_s == estimate.id.to_s

        {
          start_date: appointment.start_date,
          due_date: appointment.due_date,
          assignee: appointment.user,
          vehicle_id: appointment.vehicle_id,
          project: appointment.project,
          description: "The purpose of this work is to bill the time spent on this issue for Estimate ##{estimate.doc_number} " \
                       "for Appointment: #{appointment.subject}",
          return_path: Rails.application.routes.url_helpers.customer_appointment_path(appointment),
          return_label: appointment.subject
        }
      end

    end
  end
end
