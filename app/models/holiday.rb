#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Holiday < ApplicationRecord

  TYPES = %w[
      fixed
      dynamic
  ]

  validates :recurrence_type, inclusion: { in: TYPES }, allow_blank: true

  def occurs_on?(target_date)
    if !is_recurring
      return exact_date == target_date
    end

    if recurrence_type == 'fixed'
      return target_date.month == exact_date.month && target_date.day == exact_date.day
    end

    if recurrence_type == 'dynamic'
      # Check if month and day of week match
      return false unless target_date.month == month && target_date.wday == day_of_week
      
      # Calculate if it's the correct week of the month (1st, 2nd, 3rd, etc.)
      week_in_month = ((target_date.day - 1) / 7) + 1
      return week_in_month == week_of_month
    end

    false
  end
end