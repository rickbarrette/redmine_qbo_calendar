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
  before_action :find_appointment, only: [ :show, :edit, :update, :destroy, :issues_preview, :create_issues ]
  # This tells Redmine to check global permissions for the current controller/action
  before_action :authorize_global

  helper :projects
  helper :custom_fields

  def customer_options
    customer = Customer.find_by(id: params[:customer_id])

    render json: {
      vehicles: customer&.vehicles&.map { |v| { id: v.id, name: v.name } } || [],
      estimates: customer&.estimates&.map { |e| { id: e.id, name: e.name } } || []
    }
  end

  # Preview of the issues that can be created from the appointment's QBO estimate.
  # Each line gets a tracker and (optionally) a template before anything is created.
  def issues_preview
    load_issue_preview
  end

  # Creates the issues selected on the preview page, all or nothing.
  def create_issues
    load_issue_preview
    return if performed?

    @rows = params[:lines].respond_to?(:to_unsafe_h) ? params[:lines].to_unsafe_h : {}
    @custom_field_values = submitted_custom_field_values
    created_issues = @builder.create_issues(project: @target_project, rows: @rows,
                                            custom_field_values: @custom_field_values)

    if created_issues.any?
      flash[:notice] = l(:notice_appointment_issues_created, count: created_issues.size)
      redirect_to customer_appointment_path(@appointment)
    else
      # Rebuild the fields so the form keeps what was entered
      @field_set = RedmineQboCalendar::IssueFieldSet.new(project: @target_project, trackers: @trackers,
                                                         values: @custom_field_values)
      render :issues_preview, status: :unprocessable_entity
    end
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
  end

  def new
    @appointment = CustomerAppointment.new
    @appointment.project = @project
    @appointment.date = (params[:start_date].to_date + 9.hours) if params[:start_date].present?
    @appointment.customer_id = params[:customer_id] if params[:customer_id].present?
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

  # Sets up everything the preview page needs: the target project, its trackers and templates.
  def load_issue_preview
    @builder = RedmineQboCalendar::EstimateIssueBuilder.new(@appointment)
    @available_projects = Project.allowed_to(User.current, :add_issues).sorted.to_a

    # A project chosen on the page wins, then the appointment's project, then the first allowed one
    @target_project =
      if @project
        @project if @available_projects.include?(@project)
      elsif @available_projects.include?(@appointment.project)
        @appointment.project
      else
        @available_projects.first
      end
    return deny_access unless @target_project

    @trackers = Issue.allowed_target_trackers(@target_project, User.current).to_a
    @default_tracker = @trackers.detect { |t| t.id == RedmineQboCalendar::EstimateIssueBuilder.default_tracker_id } || @trackers.first
    @templates = RedmineQboCalendar::IssueTemplateSupport.templates_for(@target_project)
    @field_set = RedmineQboCalendar::IssueFieldSet.new(project: @target_project, trackers: @trackers)
    @rows ||= {}
  end

  # The shared custom field values from the preview form: { custom_field_id => value }
  def submitted_custom_field_values
    values = params.dig(:issue, :custom_field_values)
    values.respond_to?(:to_unsafe_h) ? values.to_unsafe_h : {}
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