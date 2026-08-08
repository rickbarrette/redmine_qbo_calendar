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
  #before_action :authorize

  helper :projects

  def customer_options
    customer = Customer.find_by(id: params[:customer_id])

    render json: {
      vehicles: customer&.vehicles&.map { |v| { id: v.id, name: v.name } } || [],
      estimates: customer&.estimates&.map { |e| { id: e.id, name: e.name } } || []
    }
  end

  def index
    if params[:project_id]
      @project = Project.find(params[:project_id])
      @appointments = CustomerAppointment.where(project: @project).order(:start_date)
    else
      @appointments = CustomerAppointment.order(:start_date)
    end
  end

  def show
    @appointment = CustomerAppointment.find(params[:id])
  end

  def new
    @appointment = CustomerAppointment.new
    @appointment.project = @project
    @appointment.date = (params[:start_date].to_date + 9.hours) if params[:start_date].present?
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
    redirect_to project_customer_appointments_path( @project)
  end

  private

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

  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  end

  def find_appointment
    @appointment = CustomerAppointment.find(params[:id])
  end

  def log(msg)
    Rails.logger.info "[CustomerAppointmentsController] #{msg}"
  end

end