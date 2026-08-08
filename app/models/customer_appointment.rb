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

  STATUSES = %w[
      Scheduled
      CheckedIn
      InProgress
      Ready
      Completed
      Cancelled
  ]

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

  private

  def log(msg)
    Rails.logger.info "[Event] #{msg}"
  end

end