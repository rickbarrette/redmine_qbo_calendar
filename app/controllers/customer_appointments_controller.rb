#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO CustomerAppointment SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class CustomerAppointmentsController < ApplicationController
  before_action :require_login
  before_action :find_project, except: [:index]
  before_action :find_appointment, only: [ :show, :edit, :update, :destroy ]
  # This tells Redmine to check global permissions for the current controller/action
  before_action :authorize_global

  def customer_options
    customer = Customer.find_by(id: params[:customer_id])

    # { select's id => [{ id:, name: }] }: the estimates, and other plugins' lists (:qbo_calendar_customer_options)
    options = { 'appointment_estimate_id' => customer&.estimates&.map { |e| { id: e.id, name: e.name } } || [] }
    options.merge!(RedmineQboCalendar.hook_hash(:qbo_calendar_customer_options, customer: customer)) if customer
    render json: { options: options }
  end

  # The estimate's labor hours (redmine_qbo's labor products/services), so the form can make sure the
  # appointment's hours aren't less
  def estimate_hours
    estimate = Estimate.find_by(id: params[:estimate_id])
    render json: { hours: CustomerAppointment.estimate_labor_hours(estimate) }
  end

  def index
    # The list shows each one's customer and technician (and plugins' fields): read with the appointments, not one by one
    @appointments = CustomerAppointment.includes(*CustomerAppointment.list_includes)
                                       .where('date >= ?', Time.zone.now.beginning_of_day).order(:date)
    if params[:project_id]
      @project = Project.find(params[:project_id])
      @appointments = @appointments.where(project: @project)
    end
  end

  # Lists past appointments, optionally filtered by customer, status and date range.
  def history
    @customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
    @status = params[:status].presence
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])

    scope = CustomerAppointment
      .includes(*CustomerAppointment.list_includes)
      .where('date < ?', Time.zone.now.beginning_of_day)
    scope = scope.where(customer_id: @customer.id) if @customer
    # The status filter also offers call-outs, which have no status
    if @status == CustomerAppointment::CALL_OUT
      scope = scope.where(event_type: CustomerAppointment::CALL_OUT)
    elsif @status
      scope = scope.where(status: @status).where(event_type: [nil, ''])
    end
    scope = scope.where('date >= ?', @from.in_time_zone.beginning_of_day) if @from
    scope = scope.where('date <= ?', @to.in_time_zone.end_of_day) if @to

    @appointment_count = scope.count
    @appointment_pages = Paginator.new(@appointment_count, per_page_option, params[:page])
    @appointments = scope
      .order(date: :desc)
      .offset(@appointment_pages.offset)
      .limit(@appointment_pages.per_page)
  end

  def show
    @appointment = CustomerAppointment.find(params[:id])
    # Issues linked to the appointment's estimate (made from it, or linked by hand)
    @estimate_issues = @appointment.estimate_id ? Issue.visible.where(estimate_id: @appointment.estimate_id).order(:id).to_a : []
  end

  def new
    @appointment = CustomerAppointment.new
    @appointment.project = @project
    # The calendar's "call-out" link makes an employee's call-out instead of a customer appointment
    @appointment.event_type = CustomerAppointment::CALL_OUT if params[:event_type] == CustomerAppointment::CALL_OUT
    @appointment.status = RedmineQboCalendar::AppointmentStatus.default.key unless @appointment.call_out?
    @appointment.date = (params[:start_date].to_date + 9.hours) if params[:start_date].present?
    @appointment.customer_id = params[:customer_id] if params[:customer_id].present?
    prefill_estimate
    # Other plugins fill in their own fields from the link's params (e.g. the vehicle ticked on a customer page)
    Redmine::Hook.call_hook(:qbo_calendar_new_appointment, appointment: @appointment, params: params)
    # Warn up front when the day picked on the calendar is in a no-new-work week
    @no_work_weeks = @appointment.no_work_weeks_added
  end

  def create
    @appointment = CustomerAppointment.new(appointment_params)
    @appointment.project = @project
    apply_no_work_week_override
    if @appointment.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to customer_appointment_path( @appointment )
    else
      render :new, status: :unprocessable_entity
    end

  end

  def edit
  end

  def update
    @appointment.assign_attributes(appointment_params)
    apply_no_work_week_override
    if @appointment.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to customer_appointment_path( @appointment )
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to issues_calendar_path
  end

  private

  # "Schedule anyway" on the form counts only for users with "Override no-new-work weeks"
  def apply_no_work_week_override
    @appointment.no_work_week_override = params[:override_no_work_week] == '1' && can_override_no_work_weeks?
  end

  def can_override_no_work_weeks?
    User.current.allowed_to?(:override_no_work_weeks, nil, global: true)
  end
  helper_method :can_override_no_work_weeks?

  # Links from an estimate (redmine_qbo) pass the estimate, used only when it belongs to the appointment's customer
  def prefill_estimate
    customer = @appointment.customer
    return unless customer

    if params[:estimate_id].present? && customer.estimates.exists?(id: params[:estimate_id])
      @appointment.estimate_id = params[:estimate_id]
      # At least the estimate's labor hours
      labor = CustomerAppointment.estimate_labor_hours(@appointment.estimate)
      @appointment.estimated_hours = labor if labor > @appointment.estimated_hours.to_i
    end
  end

  def appointment_params

    params
      .require(:customer_appointment)
      .permit(
        :subject,
        :customer_id,
        :phone,
        :description,
        :status,
        :event_type,
        :user_id,
        :date,
        :estimated_hours,
        :estimate_id,
        :partial_estimate,
        :duration,
        # Other plugins' fields (:qbo_calendar_appointment_attributes)
        *RedmineQboCalendar.hook_list(:qbo_calendar_appointment_attributes)
      )

  end

  def parse_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError
    nil
  end

  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  end

  def find_appointment
    @appointment = CustomerAppointment.find(params[:id])
  rescue
    render_404
  end

  def log(msg)
    Rails.logger.info "[CustomerAppointmentsController] #{msg}"
  end

end