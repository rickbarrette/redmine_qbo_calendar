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

  validates :subject, presence: true
  validates :date, presence: true

  normalizes :subject, with: ->(subject) { subject.strip.titleize }

  STATUSES = %w[
      Scheduled
      CheckedIn
      InProgress
      Ready
      Completed
      Cancelled
  ]

  # Scans the QBO Estimate's InvoiceLineItems for "Labor" sales items
  # and generates a Redmine Issue for each matching line.
  #
  # @param project [Project] Target project (defaults to appointment's project)
  # @param author [User] Author for the new issues
  # @param tracker [Tracker] Target tracker (defaults to project's first tracker)
  # @return [Array<Issue>] Created issues
  def create_issues_from_labor_lines(project: self.project, author: User.current, tracker: nil)
    return [] if estimate.blank?

    target_project = project || self.project || Project.first
    target_tracker = tracker || target_project&.trackers&.first
    return [] unless target_project && target_tracker

    created_issues = []

    # estimate.line_items returns array of Quickbooks::Model::InvoiceLineItem
    estimate.line_items.each do |line|
      detail = line.respond_to?(:sales_line_item_detail) ? line.sales_line_item_detail : nil
      next if detail.nil? || detail.item_ref.nil?

      item_name = detail.item_ref.name.to_s.strip
      description = line.description.to_s.strip

      # Match "Labor" (case-insensitive) and ensure description is present
      next unless item_name.casecmp('Labor').zero?
      next if description.blank?

      # detail.quantity contains line quantity/hours; line.amount is total line cost fallback
      qty = detail.respond_to?(:quantity) ? detail.quantity.to_f : 0.0
      hours = qty.positive? ? qty : line.amount.to_f

      issue = Issue.new(
        project: target_project,
        tracker: target_tracker,
        assigned_to_id: self.user&.id,
        author: author,
        subject: description.truncate(255),
        description: "The purpose of this work is to bill the time spent on this issue for Estimate ##{estimate.doc_number} for Appointment: #{subject}",
        estimated_hours: hours,
        start_date: self.start_date,
        due_date: self.due_date,
        vehicle: self.vehicle,
        estimate: self.estimate,
        customer: self.customer,
        created_on: Time.current,
        updated_on: Time.current
      )

      if issue.save
        created_issues << issue
      else
        log "Failed to create issue for Estimate ##{estimate.id}: #{issue.errors.full_messages.join(', ')}"
      end
    end

    created_issues
  end

  # Cast datetime to Date for Redmine Calendar compatibility
  def start_date
    date&.to_date
  end

  def due_date
    return nil unless date
    # Accounts for multi-day duration spanning across dates
    start_date + ([duration.to_i, 1].max - 1).days
  end

  def self.visible(user)
    return CustomerAppointment.all
  end

  def to_s
    subject
  end

  private

  def log(msg)
    Rails.logger.info "[CustomerAppointment] #{msg}"
  end

  # Helper to parse item name across Quickbooks::Model::Line and Hash structures
  def extract_item_name(line)
    if line.respond_to?(:sales_line_item_detail) && line.sales_line_item_detail.present?
      line.sales_line_item_detail.item_ref&.name
    elsif line.is_a?(Hash)
      line[:item_name] || line.dig('sales_line_item_detail', 'item_ref', 'name')
    end
  end

  # Helper to parse description across Quickbooks::Model::Line and Hash structures
  def extract_description(line)
    if line.respond_to?(:description)
      line.description
    elsif line.is_a?(Hash)
      line[:description] || line['description']
    end
  end

end