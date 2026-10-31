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

    render json: {
      vehicles: customer&.vehicles&.map { |v| { id: v.id, name: v.name } } || [],
      estimates: customer&.estimates&.map { |e| { id: e.id, name: e.name } } || []
    }
  end

  # The estimate's labor hours (redmine_qbo's labor products/services), so the form can make sure the
  # appointment's hours aren't less
  def estimate_hours
    estimate = Estimate.find_by(id: params[:estimate_id])
    render json: { hours: CustomerAppointment.estimate_labor_hours(estimate) }
  end

  def index
    if params[:project_id]
      @project = Project.find(params[:project_id])
      @appointments = CustomerAppointment.where(project: @project).where('date >= ?', Time.zone.now.beginning_of_day).order(:date)
    else
      @appointments = CustomerAppointment.where('date >= ?', Time.zone.now.beginning_of_day).order(:date)
    end
  end

  # Lists past appointments, optionally filtered by customer, status and date range.
  def history
    @customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
    @status = params[:status].presence
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])

    scope = CustomerAppointment
      .includes(:customer, :vehicle, :user)
      .where('date < ?', Time.zone.now.beginning_of_day)
    scope = scope.where(customer_id: @customer.id) if @customer
    scope = scope.where(status: @status) if @status
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
    @appointment.date = (params[:start_date].to_date + 9.hours) if params[:start_date].present?
    @appointment.customer_id = params[:customer_id] if params[:customer_id].present?
    prefill_estimate_and_vehicle
  end

  def create
    @appointment = CustomerAppointment.new(appointment_params)
    @appointment.project = @project
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
    if @appointment.update( appointment_params )
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

  # Links from an estimate (redmine_qbo) pass the estimate and vehicle; each is used only when it
  # belongs to the appointment's customer
  def prefill_estimate_and_vehicle
    customer = @appointment.customer
    return unless customer

    if params[:estimate_id].present? && customer.estimates.exists?(id: params[:estimate_id])
      @appointment.estimate_id = params[:estimate_id]
      # At least the estimate's labor hours
      labor = CustomerAppointment.estimate_labor_hours(@appointment.estimate)
      @appointment.estimated_hours = labor if labor > @appointment.estimated_hours.to_i
    end
    if params[:vehicle_id].present? && customer.respond_to?(:vehicles) && customer.vehicles.exists?(id: params[:vehicle_id])
      @appointment.vehicle_id = params[:vehicle_id]
    end
  end

  def appointment_params

    params
      .require(:customer_appointment)
      .permit(
        :subject,
        :customer_id,
        :phone,
        :vehicle_id,
        :description,
        :status,
        :user_id,
        :date,
        :estimated_hours,
        :estimate_id,
        :duration
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