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

class AppointmentFilterTest < ActiveSupport::TestCase
  include QboCalendarTestHelper

  def setup
    User.current = User.find(2)
    @jane = create_customer
    @bob = create_customer(9502, 'Bob Builder')
    @mine = create_appointment(user_id: 2, customer_id: @jane.id, project_id: 1)
    @dave = create_appointment(user_id: 3, customer_id: @bob.id, project_id: 2)
    @nobody = create_appointment(user_id: nil, customer_id: nil, project_id: nil)
    @call_out = create_call_out(user_id: 8)
  end

  def teardown
    User.current = nil
  end

  def filtered(field, operator, values = [])
    query = IssueQuery.new(name: '_', project: nil)
    query.add_filter(field, operator, values)
    RedmineQboCalendar::AppointmentFilter.new(query, user: User.find(2)).apply(CustomerAppointment.all).to_a
  end

  def test_by_assignee
    assert_equal [@mine], filtered('assigned_to_id', '=', ['me'])
    assert_equal [@dave], filtered('assigned_to_id', '=', ['3'])
    assert_equal [@mine, @nobody], filtered('assigned_to_id', '!', ['3', '8']).sort_by(&:id)
    assert_equal [@nobody], filtered('assigned_to_id', '!*')
    assert_equal 3, filtered('assigned_to_id', '*').size
  end

  def test_a_group_stands_for_its_members
    # Group 10 (A Team) has user 8
    assert_equal [@call_out], filtered('assigned_to_id', '=', ['10'])
  end

  def test_by_customer
    assert_equal [@mine], filtered('customer_name', '~', ['jane'])
    # Call-outs and appointments without a customer stay
    assert_equal [@dave, @nobody, @call_out], filtered('customer_name', '!~', ['jane']).sort_by(&:id)
  end

  def test_by_project
    assert_equal [@dave], filtered('project_id', '=', ['2'])
    assert_equal [@dave, @nobody, @call_out], filtered('project_id', '!', ['1']).sort_by(&:id)
    assert_equal [@mine, @dave], filtered('project_id', '*').sort_by(&:id)
    assert_equal [@nobody, @call_out], filtered('project_id', '!*').sort_by(&:id)
    # jsmith is a member of projects 1, 2 and 5
    assert_equal [@mine, @dave], filtered('project_id', '=', ['mine']).sort_by(&:id)
  end

  def test_issue_only_filters_leave_appointments_alone
    query = IssueQuery.new(name: '_')
    query.add_filter('status_id', 'o')
    filter = RedmineQboCalendar::AppointmentFilter.new(query)
    assert_equal [], filter.applied_fields
    assert_equal 4, filter.apply(CustomerAppointment.all).count
    assert_equal [], RedmineQboCalendar::AppointmentFilter.new(nil).applied_fields
  end
end
