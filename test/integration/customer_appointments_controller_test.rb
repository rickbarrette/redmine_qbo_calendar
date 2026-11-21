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

class CustomerAppointmentsControllerTest < Redmine::IntegrationTest
  include QboCalendarTestHelper

  def setup
    @customer = create_customer
    @appointment = create_appointment(customer_id: @customer.id)
  end

  def login(*permissions)
    allow(*permissions)
    reset!
    log_user('jsmith', 'jsmith')
  end

  def appointment_params(extra = {})
    { subject: 'brake job', customer_id: @customer.id, user_id: 2, date: '2026-11-24T09:00', duration: 1,
      estimated_hours: 3, status: 'Scheduled' }.merge(extra)
  end

  def test_anonymous_users_log_in
    get '/customer_appointments'
    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  def test_pages_need_permissions
    login
    get '/customer_appointments'
    assert_response :forbidden
    get "/customer_appointments/#{@appointment.id}"
    assert_response :forbidden
    get '/customer_appointments/history'
    assert_response :forbidden

    login(:view_customer_appointments)
    get '/customer_appointments/new'
    assert_response :forbidden
    post '/customer_appointments', params: { customer_appointment: appointment_params }
    assert_response :forbidden
    get "/customer_appointments/#{@appointment.id}/edit"
    assert_response :forbidden
    patch "/customer_appointments/#{@appointment.id}", params: { customer_appointment: { status: 'Ready' } }
    assert_response :forbidden
    delete "/customer_appointments/#{@appointment.id}"
    assert_response :forbidden
    get '/customer_appointments/customer_options', params: { customer_id: @customer.id }
    assert_response :forbidden
    assert_equal 'Scheduled', @appointment.reload.status
  end

  def test_index_lists_upcoming_appointments
    past = create_appointment(date: Date.new(2026, 11, 16), subject: 'Old job')
    other_project = create_appointment(project_id: 2, subject: 'Other shop')
    login(:view_customer_appointments)
    get '/customer_appointments'
    assert_response :success
    assert_select 'a[href=?]', "/customer_appointments/#{@appointment.id}"
    assert_select 'a[href=?]', "/customer_appointments/#{other_project.id}"
    assert_select 'a[href=?]', "/customer_appointments/#{past.id}", count: 0

    get '/customer_appointments', params: { project_id: 1 }
    assert_response :success
    assert_select 'a[href=?]', "/customer_appointments/#{other_project.id}", count: 0
  end

  def test_history
    past = create_appointment(date: Date.new(2026, 11, 16), customer_id: @customer.id, status: 'Completed')
    older = create_appointment(date: Date.new(2026, 10, 5), customer_id: @customer.id, status: 'Cancelled')
    call_out = create_call_out(date: Date.new(2026, 11, 17))
    login(:view_customer_appointments)

    get '/customer_appointments/history'
    assert_response :success
    assert_select 'table.appointment-history td.subject', 3
    assert_select 'td.subject a[href=?]', "/customer_appointments/#{@appointment.id}", count: 0

    get '/customer_appointments/history', params: { status: 'Completed' }
    assert_select 'td.subject a', 1
    assert_select 'td.subject a[href=?]', "/customer_appointments/#{past.id}"

    get '/customer_appointments/history', params: { status: 'call_out' }
    assert_select 'td.subject a[href=?]', "/customer_appointments/#{call_out.id}"
    assert_select 'td.subject a', 1

    get '/customer_appointments/history', params: { customer_id: @customer.id, from: '2026-11-01', to: 'not a date' }
    assert_select 'td.subject a', 1
    get '/customer_appointments/history', params: { to: '2026-10-31' }
    assert_select 'td.subject a[href=?]', "/customer_appointments/#{older.id}"
    assert_select 'td.subject a', 1
  end

  def test_show
    estimate = create_estimate
    @appointment.update_columns(estimate_id: estimate.id)
    issue = Issue.find(1)
    issue.update_columns(estimate_id: estimate.id)
    login(:view_customer_appointments)
    get "/customer_appointments/#{@appointment.id}"
    assert_response :success
    assert_select '.appointment-title', text: 'Lift kit install'
    assert_select '.status-badge', text: 'Scheduled'
    assert_select 'a[href=?]', "/issues/#{issue.id}"
    assert_select '.quick-status-btn', 0
    assert_select 'a[href=?]', "/customer_appointments/#{@appointment.id}/edit", count: 0
    assert_select 'a[href=?]', "/customer_appointments/history?customer_id=#{@customer.id}"
  end

  def test_show_with_every_permission
    login(*PERMISSIONS)
    get "/customer_appointments/#{@appointment.id}"
    # One button per other status
    assert_select '.quick-status-btn', 5
    assert_select 'a[href=?]', "/customer_appointments/#{@appointment.id}/edit"
    assert_select 'a[data-method=delete][href=?]', "/customer_appointments/#{@appointment.id}"
    get '/customer_appointments/424242'
    assert_response :not_found
  end

  def test_show_a_call_out
    call_out = create_call_out
    login(:view_customer_appointments, :edit_customer_appointments, :add_customer_appointments)
    get "/customer_appointments/#{call_out.id}"
    assert_response :success
    assert_select '.status-call-out'
    assert_select '.quick-status-btn', 0
    assert_select 'a[href^="/issues/new"]', 0
  end

  def test_new_from_the_calendar
    login(:view_customer_appointments, :add_customer_appointments)
    get '/customer_appointments/new', params: { start_date: '2026-11-24', customer_id: @customer.id }
    assert_response :success
    assert_select 'input[name=?][value^=?]', 'customer_appointment[date]', '2026-11-24T09:00'
    assert_select 'input#customer_id[value=?]', @customer.id.to_s
    assert_select 'select[name=?] option[selected][value=?]', 'customer_appointment[status]', 'Scheduled'
  end

  def test_new_from_an_estimate
    estimate = create_estimate
    other = create_estimate(id: 9502, customer: create_customer(9502, 'Bob Builder'), doc_number: '2000')
    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(6.5)
    login(:view_customer_appointments, :add_customer_appointments)
    get '/customer_appointments/new', params: { customer_id: @customer.id, estimate_id: estimate.id }
    assert_select 'select#appointment_estimate_id option[selected][value=?]', estimate.id.to_s
    assert_select 'input[name=?][value=?]', 'customer_appointment[estimated_hours]', '7'

    # Another customer's estimate isn't used
    get '/customer_appointments/new', params: { customer_id: @customer.id, estimate_id: other.id }
    assert_select 'select#appointment_estimate_id option[selected]', 0
  end

  def test_new_call_out
    login(:view_customer_appointments, :add_customer_appointments)
    get '/customer_appointments/new', params: { event_type: 'call_out', start_date: '2026-11-24' }
    assert_response :success
    assert_select 'input[type=hidden][name=?][value=?]', 'customer_appointment[event_type]', 'call_out'
    assert_select 'select[name=?]', 'customer_appointment[status]', 0
  end

  def test_new_warns_about_a_no_work_week
    NoWorkWeek.flag!(Date.new(2026, 11, 30))
    login(:view_customer_appointments, :add_customer_appointments)
    get '/customer_appointments/new', params: { start_date: '2026-12-01' }
    assert_select '.flash.warning', text: /12\/01\/2026|11\/30\/2026|2026-11-30/
    assert_select 'input#override_no_work_week', 0
  end

  def test_create
    login(:view_customer_appointments, :add_customer_appointments)
    assert_difference('CustomerAppointment.count', 1) do
      post '/customer_appointments', params: { project_id: 1, customer_appointment: appointment_params }
    end
    appointment = CustomerAppointment.order(:id).last
    assert_redirected_to "/customer_appointments/#{appointment.id}"
    assert_equal 'Brake job', appointment.subject
    assert_equal Project.find(1), appointment.project
    assert_equal Time.zone.local(2026, 11, 24, 9), appointment.date
  end

  def test_create_on_a_weekend_is_refused
    login(:view_customer_appointments, :add_customer_appointments)
    assert_no_difference('CustomerAppointment.count') do
      post '/customer_appointments', params: { customer_appointment: appointment_params(date: '2026-11-21T09:00') }
    end
    assert_response :unprocessable_entity
    assert_select '#errorExplanation', text: /#{Regexp.escape(I18n.t(:error_non_working_day))}/
  end

  def test_no_work_weeks_need_the_override_permission
    NoWorkWeek.flag!(Date.new(2026, 11, 30))
    params = { customer_appointment: appointment_params(date: '2026-12-01T09:00'), override_no_work_week: '1' }
    login(:view_customer_appointments, :add_customer_appointments)
    assert_no_difference('CustomerAppointment.count') { post '/customer_appointments', params: params }
    assert_response :unprocessable_entity
    assert_select 'input#override_no_work_week', 0

    login(:view_customer_appointments, :add_customer_appointments, :override_no_work_weeks)
    post '/customer_appointments', params: params.except(:override_no_work_week)
    assert_response :unprocessable_entity
    assert_select 'input#override_no_work_week'
    assert_difference('CustomerAppointment.count', 1) { post '/customer_appointments', params: params }
  end

  def test_update_and_quick_status
    login(:view_customer_appointments, :edit_customer_appointments)
    get "/customer_appointments/#{@appointment.id}/edit"
    assert_response :success
    patch "/customer_appointments/#{@appointment.id}", params: { customer_appointment: { status: 'Checked_In' } }
    assert_redirected_to "/customer_appointments/#{@appointment.id}"
    assert_equal 'Checked_In', @appointment.reload.status

    patch "/customer_appointments/#{@appointment.id}", params: { customer_appointment: { subject: '' } }
    assert_response :unprocessable_entity
  end

  def test_destroy
    login(:view_customer_appointments, :delete_customer_appointments)
    delete "/customer_appointments/#{@appointment.id}"
    assert_redirected_to '/issues/calendar'
    assert_not CustomerAppointment.exists?(@appointment.id)
  end

  def test_customer_options_and_estimate_hours
    estimate = create_estimate
    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(3.2)
    login(:edit_customer_appointments)
    get '/customer_appointments/customer_options', params: { customer_id: @customer.id }
    assert_response :success
    assert_equal [{ 'id' => estimate.id, 'name' => estimate.name }], response.parsed_body['options']['appointment_estimate_id']
    get '/customer_appointments/customer_options', params: { customer_id: 424242 }
    assert_equal({ 'options' => { 'appointment_estimate_id' => [] } }, response.parsed_body)

    get '/customer_appointments/estimate_hours', params: { estimate_id: estimate.id }
    assert_equal({ 'hours' => 4 }, response.parsed_body)
    get '/customer_appointments/estimate_hours', params: { estimate_id: 424242 }
    assert_equal({ 'hours' => 0 }, response.parsed_body)
  end

  # Stands in for another plugin's appointment field (as redmine_qbo_vehicles adds the vehicle); only while @on
  class PluginFieldListener < Redmine::Hook::ViewListener
    class << self
      attr_accessor :on
    end

    def qbo_calendar_appointment_attributes(_context = {})
      [:project_id] if self.class.on
    end

    def qbo_calendar_appointment_preloads(_context = {})
      [:project] if self.class.on
    end

    def qbo_calendar_new_appointment(context = {})
      context[:appointment].estimated_hours = 7 if self.class.on && context[:params][:plugin_hours]
    end

    def qbo_calendar_customer_options(context = {})
      { 'appointment_plugin_id' => [{ id: 1, name: context[:customer].name }] } if self.class.on
    end

    def qbo_calendar_new_issue_params(_context = {})
      { plugin_field: 'x' } if self.class.on
    end

    %w[form_details show_details tooltip calendar_event].each do |hook|
      define_method("view_customer_appointments_#{hook}") do |_context = {}|
        self.class.on ? "<span class=\"plugin-#{hook.dasherize}\"></span>".html_safe : ''
      end
    end

    def view_customer_appointments_list_header(context = {})
      self.class.on ? "<th class=\"plugin-#{context[:list]}\"></th>".html_safe : ''
    end

    def view_customer_appointments_list_row(context = {})
      self.class.on ? "<td class=\"plugin-row-#{context[:appointment].id}\"></td>".html_safe : ''
    end
  end

  def test_other_plugins_add_fields_through_hooks
    PluginFieldListener.on = true
    login(:view_customer_appointments, :add_customer_appointments, :edit_customer_appointments)

    get '/customer_appointments/new', params: { customer_id: @customer.id, plugin_hours: '1' }
    assert_select '.plugin-form-details'
    assert_select 'input[name=?][value="7"]', 'customer_appointment[estimated_hours]'
    assert_includes CustomerAppointment.list_includes, :project

    get "/customer_appointments/#{@appointment.id}"
    assert_select '.plugin-show-details'
    assert_select 'a[href*=?]', 'issue%5Bplugin_field%5D=x'

    patch "/customer_appointments/#{@appointment.id}", params: { customer_appointment: { project_id: 2 } }
    assert_equal 2, @appointment.reload.project_id

    get '/customer_appointments/customer_options', params: { customer_id: @customer.id }
    assert_equal [{ 'id' => 1, 'name' => 'Jane Customer' }], response.parsed_body['options']['appointment_plugin_id']

    get '/customer_appointments'
    assert_select 'th.plugin-index'
    assert_select "td.plugin-row-#{@appointment.id}"
    create_appointment(date: Date.new(2026, 11, 16))
    get '/customer_appointments/history'
    assert_select 'th.plugin-history'
    get '/issues/calendar', params: { year: 2026, month: 11 }
    assert_select '.plugin-calendar-event'
    assert_select '.plugin-tooltip'
  ensure
    PluginFieldListener.on = false
  end

  def test_plugin_fields_are_not_saved_without_a_plugin
    login(:view_customer_appointments, :edit_customer_appointments)
    patch "/customer_appointments/#{@appointment.id}", params: { customer_appointment: { project_id: 2 } }
    assert_equal 1, @appointment.reload.project_id
  end
end
