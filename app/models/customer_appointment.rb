#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class CustomerAppointment < ActiveRecord::Base

  belongs_to :project, optional: true
  belongs_to :user, optional: true
  belongs_to :customer, optional: true
  belongs_to :vehicle, optional: true
  belongs_to :estimate, optional: true

  # Issues created from this appointment's estimate lines
  has_many :appointment_estimate_issues, dependent: :nullify
  has_many :created_issues, through: :appointment_estimate_issues, source: :issue

  validates :subject, presence: true
  validates :date, presence: true
  
  # Prevent scheduling on non-working days or holidays
  validate :validate_working_day

  # The hours can't be less than the attached estimate's labor hours
  validate :validate_hours_cover_estimate

  # Capitalize the first letter only; titleize mangled vehicle names and acronyms (JL -> Jl, LED -> Led)
  normalizes :subject, with: ->(subject) { subject.strip.sub(/\A[a-z]/, &:upcase) }

  STATUSES = %w[
      Scheduled
      Checked_In
      In_Progress
      Ready
      Completed
      Cancelled
      Call_Out
  ]

  # Statuses whose time should not count toward scheduled hours totals
  NON_SCHEDULED_STATUSES = %w[
      Cancelled
      Call_Out
  ]

  # False for cancelled / call-out appointments, which stay on the calendar but free up their hours
  def counts_toward_hours?
    !NON_SCHEDULED_STATUSES.include?(status.to_s)
  end

  # Cast datetime to Date for Redmine Calendar compatibility
  def start_date
    date&.to_date
  end

  # Last working day of the appointment. Weekends and holidays are skipped, matching how the
  # calendar spreads a multi-day appointment (a 3-day job starting Friday ends Tuesday).
  def due_date
    return nil unless date
    @due_date_cache ||= {}
    @due_date_cache[[start_date, duration.to_i]] ||=
      RedmineQboCalendar::WorkingDays.nth_working_day(start_date, duration)
  end

  # Appointments the user may see. Requires the global "View customer appointments" permission.
  def self.visible(user = User.current)
    if user.allowed_to?(:view_customer_appointments, nil, global: true)
      all
    else
      none
    end
  end

  def to_s
    subject
  end

  # The estimate's labor hours rounded up to whole hours (appointment hours are whole numbers): the
  # quantities of its lines whose item matches redmine_qbo's item codes (e.g. Labor). 0 if the
  # estimate can't be read from QuickBooks.
  def self.estimate_labor_hours(estimate)
    return 0 if estimate.nil?
    RedmineQboBilling::EstimateIssueBuilder.labor_hours(estimate).ceil
  rescue StandardError => e
    Rails.logger.warn "[CustomerAppointment] Could not read labor hours for estimate #{estimate&.id}: #{e.message}"
    0
  end

  private

  def log(msg)
    Rails.logger.info "[CustomerAppointment] #{msg}"
  end

  # Checked when the estimate or the hours change, so changing just the status (the quick status buttons)
  # never fails on an older appointment
  def validate_hours_cover_estimate
    return if estimate.nil?
    return unless new_record? || will_save_change_to_estimate_id? || will_save_change_to_estimated_hours?

    labor = self.class.estimate_labor_hours(estimate)
    return if labor.zero? || estimated_hours.to_i >= labor

    errors.add(:base, I18n.t(:error_hours_less_than_estimate, hours: labor, estimate: estimate.doc_number))
  end

  # Validates that the appointment date does not land on a weekend or holiday
  def validate_working_day
    return if date.blank?

    target_date = date.to_date
    non_working_days = Setting.non_working_week_days || []

    if non_working_days.include?(target_date.cwday.to_s)
      errors.add(:date, :invalid, message: I18n.t(:error_non_working_day))
    elsif defined?(Holiday)
      matched_holiday = Holiday.all.find { |h| h.occurs_on?(target_date) }
      if matched_holiday.present?
        errors.add(:date, :invalid, message: I18n.t(:error_holiday, name: matched_holiday.name))
      end
    end
  end

end