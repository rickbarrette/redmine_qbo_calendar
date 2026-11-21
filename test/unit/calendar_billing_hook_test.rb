#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../test_helper', __dir__)

class CalendarBillingHookTest < ActiveSupport::TestCase
  include QboCalendarTestHelper

  def setup
    @hook = RedmineQboCalendar::Hooks::BillingHookListener.instance
    @estimate = create_estimate
    @appointment = create_appointment(date: Date.new(2026, 11, 27), duration: 2, estimate_id: @estimate.id,
                                      customer_id: 9501, estimated_hours: 12)
    User.current = User.find(2)
  end

  def teardown
    User.current = nil
  end

  def test_issues_created_from_an_appointment_get_its_details
    allow(:view_customer_appointments)
    defaults = @hook.qbo_billing_issue_defaults(params: { appointment_id: @appointment.id.to_s }, estimate: @estimate)
    assert_equal Date.new(2026, 11, 27), defaults[:start_date]
    assert_equal Date.new(2026, 11, 30), defaults[:due_date]
    assert_equal User.find(2), defaults[:assignee]
    assert_equal Project.find(1), defaults[:project]
    assert_equal "/customer_appointments/#{@appointment.id}", defaults[:return_path]
    assert_equal 'Lift kit install', defaults[:return_label]
    assert_match(/Estimate #1068 for Appointment: Lift kit install/, defaults[:description])
  end

  def test_only_for_viewers_and_the_appointments_own_estimate
    params = { appointment_id: @appointment.id.to_s }
    assert_nil @hook.qbo_billing_issue_defaults(params: params, estimate: @estimate)
    allow(:view_customer_appointments)
    assert_nil @hook.qbo_billing_issue_defaults(params: params, estimate: create_estimate(id: 9502, doc_number: '1069'))
    assert_nil @hook.qbo_billing_issue_defaults(params: {}, estimate: @estimate)
    assert_nil @hook.qbo_billing_issue_defaults(params: { appointment_id: '424242' }, estimate: @estimate)
  end
end
