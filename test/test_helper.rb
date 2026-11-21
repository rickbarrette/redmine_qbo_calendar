#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../../../test/test_helper', __dir__)

module QboCalendarTestHelper
  PERMISSIONS = %i[view_customer_appointments add_customer_appointments edit_customer_appointments
                   delete_customer_appointments manage_no_work_weeks override_no_work_weeks].freeze

  # "Today" in these tests: Friday 2026-11-20, 10am
  NOW = Time.zone.local(2026, 11, 20, 10)
  # Monday 2026-11-23
  MONDAY = Date.new(2026, 11, 23)

  def self.included(base)
    base.include ActiveSupport::Testing::TimeHelpers
    base.fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :issues, :trackers,
                  :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :workflows, :groups_users
    base.setup do
      travel_to NOW
      # Estimates' labor hours come from QuickBooks; tests that need them stub their own
      RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(0)
      AppointmentEstimateIssue.delete_all
      CustomerAppointment.delete_all
      Holiday.delete_all
      NoWorkWeek.delete_all
      Customer.where(id: 9500..9599).delete_all
      Estimate.where(id: 9500..9599).delete_all
      Setting.plugin_redmine_qbo_calendar = {}
      Role.find(1).remove_permission!(*PERMISSIONS)
    end
    base.teardown { travel_back }
  end

  # Gives jsmith's Manager role these calendar permissions (and only these)
  def allow(*permissions)
    role = Role.find(1)
    role.remove_permission!(*PERMISSIONS)
    permissions.each { |p| role.add_permission!(p) }
    User.current = User.find(User.current.id) if User.current.logged?
  end

  # A customer, without sending it to QuickBooks
  def create_customer(id = 9501, name = 'Jane Customer')
    customer = Customer.new(id: id, name: name)
    customer.skip_qbo_push = true
    customer.save!
    customer
  end

  def create_estimate(id: 9501, customer: nil, doc_number: '1068')
    estimate = Estimate.new(id: id, doc_number: doc_number, customer_id: (customer || Customer.find_by(id: 9501) || create_customer).id)
    estimate.save!
    estimate
  end

  def create_appointment(date: MONDAY, hour: 9, **attributes)
    CustomerAppointment.create!({ subject: 'Lift kit install', date: date.in_time_zone.change(hour: hour),
                                  duration: 1, estimated_hours: 4, user_id: 2, project_id: 1 }.merge(attributes))
  end

  def create_call_out(date: MONDAY, user_id: 3, **attributes)
    CustomerAppointment.create!({ event_type: CustomerAppointment::CALL_OUT, date: date.in_time_zone.change(hour: 8),
                                  user_id: user_id, duration: 1 }.merge(attributes))
  end

  def create_holiday(name = 'Thanksgiving', **attributes)
    Holiday.create!({ name: name, exact_date: Date.new(2026, 11, 26), is_recurring: false }.merge(attributes))
  end

  def with_calendar_settings(values)
    saved = Setting.plugin_redmine_qbo_calendar
    Setting.plugin_redmine_qbo_calendar = values
    yield
  ensure
    Setting.plugin_redmine_qbo_calendar = saved
  end
end
