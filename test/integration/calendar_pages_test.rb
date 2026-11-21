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
require File.expand_path('../../../redmine_qbo/test/qbo_fake_service', __dir__)

# The calendar page, no-new-work weeks, holidays, the plugin settings, and appointments on other pages
class CalendarPagesTest < Redmine::IntegrationTest
  include QboCalendarTestHelper
  include QboFakeServiceHelper

  def login(*permissions)
    allow(*permissions)
    reset!
    log_user('jsmith', 'jsmith')
  end

  def calendar(params = {})
    get '/issues/calendar', params: { year: 2026, month: 11 }.merge(params)
    assert_response :success
  end

  # ---- calendar ----

  def test_the_calendar_shows_appointments_to_viewers
    appointment = create_appointment(date: Date.new(2026, 11, 25), duration: 3, estimated_hours: 20)
    login(:view_customer_appointments)
    calendar
    # Wed, Fri and Mon (Thanksgiving isn't a holiday here, so Thu too): three working days
    assert_select '.appointment-block a.appointment-link[href=?]', "/customer_appointments/#{appointment.id}", 3
    assert_select '.appointment-days', text: /Day 1 of 3/
    assert_select '.monthly-appointments-total strong', text: '1'
    # Front-loaded: 8h, 8h and 4h, all within November
    assert_select '.monthly-hours-total strong', text: '20.0h'

    login
    calendar
    assert_select '.appointment-block', 0
  end

  def test_holidays_and_call_outs_on_the_calendar
    create_holiday
    call_out = create_call_out(date: Date.new(2026, 11, 24))
    cancelled = create_appointment(date: Date.new(2026, 11, 24), status: 'Cancelled', estimated_hours: 6)
    login(:view_customer_appointments)
    calendar
    assert_select 'li.calbody.holiday', 1
    assert_select '.appointment-block.call-out a[href=?]', "/customer_appointments/#{call_out.id}"
    assert_select '.appointment-block.cancelled.no-hours a[href=?]', "/customer_appointments/#{cancelled.id}"
    # Neither counts toward the month
    assert_select '.monthly-hours-total strong', text: '0.0h'
    assert_select '.monthly-appointments-total strong', text: '0'
  end

  def test_the_toggles_are_kept_in_the_users_preferences
    login(:view_customer_appointments)
    calendar
    assert_select 'input#toggle-only-appointments[checked]'
    assert_select 'input#toggle-hide-past-weeks[checked]', 0

    calendar(only_appointments: '0', hide_past_weeks: '1')
    assert_equal '0', User.find(2).pref[:qbo_calendar_only_appointments]
    assert_equal '1', User.find(2).pref[:qbo_calendar_hide_past_weeks]
    calendar
    assert_select 'input#toggle-only-appointments[checked]', 0
    assert_select 'input#toggle-hide-past-weeks[checked]'
  end

  def test_the_month_is_remembered
    login(:view_customer_appointments)
    get '/issues/calendar', params: { year: 2026, month: 9 }
    get '/issues/calendar'
    assert_select 'select#month option[selected][value="9"]'
    assert_select 'a[accesskey=p]', text: /August/
  end

  def test_the_assignee_filter_narrows_appointments
    mine = create_appointment(user_id: 2)
    daves = create_appointment(user_id: 3, subject: 'Dave job')
    login(:view_customer_appointments)
    calendar(set_filter: '1', f: ['assigned_to_id'], op: { assigned_to_id: '=' }, v: { assigned_to_id: ['me'] })
    assert_select 'a.appointment-link[href=?]', "/customer_appointments/#{mine.id}"
    assert_select 'a.appointment-link[href=?]', "/customer_appointments/#{daves.id}", 0
    assert_select '.calendar-appointment-filters'
  end

  def test_the_calendar_favicon_is_the_day
    login(:view_customer_appointments)
    calendar
    assert_select 'link[rel=icon][href*=?]', 'favicons/20'
    get '/my/page'
    assert_select 'link[rel=icon][href*=?]', 'favicons/20', 0
  end

  # ---- no-new-work weeks ----

  def test_flagging_a_week
    login(:manage_no_work_weeks)
    calendar
    assert_select 'label.no-work-week-toggle input:not([disabled])', minimum: 4

    # As the calendar's script sends it
    post '/no_work_weeks', params: { week: '2026-11-25', flagged: '1' }, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal({ 'week_start' => '2026-11-23', 'flagged' => true }, response.parsed_body)
    assert NoWorkWeek.exists?(week_start: MONDAY)

    post '/no_work_weeks', params: { week: '2026-11-23', flagged: '0' }
    assert_redirected_to '/issues/calendar'
    assert_not NoWorkWeek.exists?(week_start: MONDAY)

    post '/no_work_weeks', params: { week: 'someday', flagged: '1' }
    assert_response 422
  end

  def test_flagging_needs_manage_no_work_weeks
    NoWorkWeek.flag!(MONDAY)
    login(:view_customer_appointments)
    post '/no_work_weeks', params: { week: '2026-11-30', flagged: '1' }
    assert_response :forbidden
    calendar
    # The flag shows, but can't be changed
    assert_select 'li.week-number.no-work-week label.no-work-week-toggle input[disabled][checked]', 1
  end

  # ---- holidays ----

  def test_holidays_are_for_admins
    login(:view_customer_appointments)
    get '/holidays'
    assert_response :forbidden
  end

  def test_managing_holidays
    log_user('admin', 'admin')
    get '/holidays'
    assert_response :success
    get '/holidays/new'
    assert_response :success
    assert_difference('Holiday.count', 1) do
      post '/holidays', params: { holiday: { name: 'Thanksgiving', is_recurring: '1', recurrence_type: 'dynamic',
                                             month: '11', day_of_week: '4', week_of_month: '4' } }
    end
    assert_redirected_to '/holidays'
    holiday = Holiday.last
    assert holiday.occurs_on?(Date.new(2026, 11, 26))

    post '/holidays', params: { holiday: { name: 'Bad', recurrence_type: 'weekly' } }
    assert_response :success
    assert_select '#errorExplanation'

    get "/holidays/#{holiday.id}/edit"
    assert_response :success
    patch "/holidays/#{holiday.id}", params: { holiday: { name: 'Turkey day' } }
    assert_redirected_to '/holidays'
    assert_equal 'Turkey day', holiday.reload.name

    delete "/holidays/#{holiday.id}"
    assert_redirected_to '/holidays'
    assert_not Holiday.exists?(holiday.id)
    get '/holidays/424242/edit'
    assert_response :not_found
  end

  # ---- settings ----

  def test_removing_a_status_moves_its_appointments
    on_hold = create_appointment(status: 'On_Hold')
    Setting.plugin_redmine_qbo_calendar = { 'statuses' => [{ 'key' => 'Scheduled', 'name' => 'Scheduled', 'color' => '#1fc0ff', 'counts_hours' => '1' },
                                                          { 'key' => 'On_Hold', 'name' => 'On hold', 'color' => '#999999', 'counts_hours' => '1' }] }
    log_user('admin', 'admin')
    get '/settings/plugin/redmine_qbo_calendar'
    assert_response :success
    post '/settings/plugin/redmine_qbo_calendar', params: { settings: {
      statuses: { '0' => { key: 'Scheduled', name: 'Scheduled', color: '#1fc0ff', counts_hours: '1' } },
      hours_per_day: '9', status_moves: { 'On_Hold' => 'Scheduled' }
    } }
    assert_redirected_to '/settings/plugin/redmine_qbo_calendar'
    assert_equal 'Scheduled', on_hold.reload.status
    assert_match(/On hold/, flash[:notice])
    assert_equal 9.0, RedmineQboCalendar.hours_per_day
    assert_nil Setting.plugin_redmine_qbo_calendar['status_moves']
  end

  # ---- other pages ----

  def test_customer_page_lists_upcoming_appointments
    install_fake_quickbooks
    customer = create_customer
    upcoming = create_appointment(customer_id: customer.id)
    create_appointment(date: Date.new(2026, 11, 2), customer_id: customer.id)
    Role.find(1).add_permission!(:view_customers)
    login(:view_customer_appointments, :add_customer_appointments)
    get "/customers/#{customer.id}"
    assert_response :success
    assert_select '.customer-appointments-simple a[href=?]', "/customer_appointments/#{upcoming.id}"
    assert_select '.appointment-history-link a[href=?]', "/customer_appointments/history?customer_id=#{customer.id}"
    assert_select 'a#appointment_link[href=?]', "/customer_appointments/new?customer_id=#{customer.id}"

    login
    get "/customers/#{customer.id}"
    assert_select '.customer-appointments-simple', 0
    assert_select 'a#appointment_link', 0
  end

  def test_my_page_block
    create_appointment(date: Date.new(2026, 11, 19), duration: 3, user_id: 2, subject: 'Started yesterday')
    create_appointment(user_id: 3, subject: 'Not mine')
    User.find(2).pref.tap { |p| p.my_page_layout = { 'top' => ['upcoming_appointments'] }; p.save! }
    login
    get '/my/page'
    assert_response :success
    # Days 2 and 3 are still to come (today is the 20th)
    assert_select 'table.appointments tr.appointment-row', 2
    assert_select 'table.appointments', text: /Not mine/, count: 0
  end
end
