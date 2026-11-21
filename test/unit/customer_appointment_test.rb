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

class CustomerAppointmentTest < ActiveSupport::TestCase
  include QboCalendarTestHelper

  def test_subject_and_date_are_required
    appointment = CustomerAppointment.new
    assert_not appointment.valid?
    assert appointment.errors.added?(:subject, :blank)
    assert appointment.errors.added?(:date, :blank)
  end

  def test_defaults
    appointment = create_appointment(subject: '  lift kit for the JL ')
    assert_equal 'Lift kit for the JL', appointment.subject
    assert_equal 'Scheduled', appointment.status
    assert_nil appointment.event_type
    assert_equal '', appointment.description
    assert_equal 'Lift kit for the JL', appointment.to_s
  end

  def test_a_call_out_is_about_an_employee
    customer = create_customer
    call_out = create_call_out(customer_id: customer.id, status: 'Ready', estimated_hours: 8, partial_estimate: true)
    assert call_out.call_out?
    assert_nil call_out.customer_id
    assert_nil call_out.status
    assert_equal 0, call_out.estimated_hours
    assert_not call_out.partial_estimate
    assert_equal I18n.t(:label_call_out_subject, name: 'Dave Lopper'), call_out.subject
    assert_nil call_out.status_record
    assert_not call_out.counts_toward_hours?

    missing = CustomerAppointment.new(event_type: CustomerAppointment::CALL_OUT, date: MONDAY.in_time_zone.change(hour: 8), subject: 'Off')
    assert_not missing.valid?
    assert missing.errors.added?(:user, :blank)
  end

  def test_not_on_weekends_or_holidays
    appointment = CustomerAppointment.new(subject: 'Lift', date: Time.zone.local(2026, 11, 21, 9))
    assert_not appointment.valid?
    assert_includes appointment.errors[:date], I18n.t(:error_non_working_day)

    create_holiday
    appointment.date = Time.zone.local(2026, 11, 26, 9)
    assert_not appointment.valid?
    assert_includes appointment.errors[:date], I18n.t(:error_holiday, name: 'Thanksgiving')
  end

  def test_working_days_of_a_multi_day_appointment
    create_holiday
    appointment = create_appointment(date: Date.new(2026, 11, 25), duration: 3)
    assert_equal Date.new(2026, 11, 25), appointment.start_date
    assert_equal Date.new(2026, 11, 30), appointment.due_date
    assert_equal 2, appointment.working_day_number(Date.new(2026, 11, 27))
    assert_nil appointment.working_day_number(Date.new(2026, 11, 26))
    assert_equal [], CustomerAppointment.new.working_days
  end

  def test_cancelled_appointments_free_their_hours
    appointment = create_appointment
    assert appointment.counts_toward_hours?
    appointment.status = 'Cancelled'
    assert_not appointment.counts_toward_hours?
    assert_equal 'Cancelled', appointment.status_record.key
    appointment.status = 'On_Hold'
    assert_not appointment.status_record.known?
  end

  def test_hours_cover_the_estimates_labor
    estimate = create_estimate
    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(5.5)
    appointment = CustomerAppointment.new(subject: 'Lift', date: MONDAY.in_time_zone.change(hour: 9), estimate: estimate,
                                          estimated_hours: 5)
    assert_not appointment.valid?
    assert_includes appointment.errors[:base], I18n.t(:error_hours_less_than_estimate, hours: 6, estimate: '1068')
    appointment.estimated_hours = 6
    assert appointment.valid?
    appointment.estimated_hours = 2
    appointment.partial_estimate = true
    assert appointment.valid?
  end

  def test_status_changes_never_fail_on_the_estimate
    estimate = create_estimate
    appointment = create_appointment(estimate: estimate, estimated_hours: 2)
    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(10)
    appointment.reload.status = 'Ready'
    assert appointment.valid?
    appointment.estimated_hours = 3
    assert_not appointment.valid?
  end

  def test_estimate_labor_hours
    estimate = create_estimate
    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(2.1)
    assert_equal 3, CustomerAppointment.estimate_labor_hours(estimate)
    assert_equal 0, CustomerAppointment.estimate_labor_hours(nil)
    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).raises(StandardError, 'QuickBooks is down')
    assert_equal 0, CustomerAppointment.estimate_labor_hours(estimate)
  end

  def test_new_work_in_a_no_work_week_needs_an_override
    NoWorkWeek.flag!(Date.new(2026, 11, 30))
    appointment = CustomerAppointment.new(subject: 'Lift', date: Time.zone.local(2026, 11, 27, 9), duration: 2)
    assert_not appointment.valid?
    assert appointment.no_work_week_conflict?
    assert_equal [Date.new(2026, 11, 30)], appointment.no_work_weeks_added
    assert_match(/November 30, 2026/, appointment.errors[:base].join)

    appointment.no_work_week_override = true
    assert appointment.valid?
    assert_not appointment.no_work_week_conflict?
  end

  def test_work_already_in_the_week_can_change
    appointment = create_appointment(date: Date.new(2026, 11, 30))
    NoWorkWeek.flag!(Date.new(2026, 11, 30))
    appointment.reload.status = 'Ready'
    assert appointment.valid?
    # Moving within the week adds no new work to it
    appointment.date = Time.zone.local(2026, 12, 2, 9)
    assert appointment.valid?
    # Moving into another flagged week does
    NoWorkWeek.flag!(Date.new(2026, 12, 7))
    appointment.date = Time.zone.local(2026, 12, 8, 9)
    assert_not appointment.valid?
  end

  def test_call_outs_are_never_new_work
    NoWorkWeek.flag!(MONDAY)
    assert create_call_out.persisted?
    assert_equal [], create_call_out(user_id: 2).no_work_weeks_added
  end

  def test_visible_needs_view_customer_appointments
    create_appointment
    assert_equal 0, CustomerAppointment.visible(User.find(2)).count
    Role.find(1).add_permission!(:view_customer_appointments)
    assert_equal 1, CustomerAppointment.visible(User.find(2)).count
  end

  def test_estimate_issues_are_kept_with_their_issue
    appointment = create_appointment
    issue = Issue.generate!(project_id: 1)
    link = AppointmentEstimateIssue.create!(customer_appointment: appointment, issue: issue, estimate_id: 9501, line_id: '2')
    assert link.created_on
    assert_equal appointment, issue.reload.customer_appointment
    assert_equal [issue], appointment.created_issues.to_a

    duplicate = AppointmentEstimateIssue.new(issue: issue, estimate_id: 9501, line_id: '2')
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:line_id, :taken)

    # Deleting the appointment keeps the link (the line was made); deleting the issue frees the line
    appointment.destroy
    assert_nil link.reload.customer_appointment_id
    issue.destroy
    assert_not AppointmentEstimateIssue.exists?(link.id)
  end

  def test_customers_and_users_have_appointments
    customer = create_customer
    appointment = create_appointment(customer_id: customer.id)
    assert_equal [appointment], customer.customer_appointments.to_a
    assert_equal [appointment], User.find(2).customer_appointments.to_a
  end
end
