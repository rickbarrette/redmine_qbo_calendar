#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module RedmineQboCalendar
  # Working-day arithmetic that respects Redmine's non-working week days and Holidays.
  module WorkingDays
    # Upper bound on how far we'll walk the calendar, so bad data can't loop forever.
    MAX_SCAN_DAYS = 3660

    module_function

    def non_working_week_days
      Setting.non_working_week_days || []
    end

    def non_working?(date, holidays: Holiday.all.to_a, week_days: non_working_week_days)
      week_days.include?(date.cwday.to_s) || holidays.any? { |h| h.occurs_on?(date) }
    end

    # Returns the date of the Nth working day, counting start_date itself if it is a working day.
    # e.g. a 3-day job starting Friday ends on Tuesday (Fri, Mon, Tue).
    def nth_working_day(start_date, count, holidays: Holiday.all.to_a, week_days: non_working_week_days)
      return nil if start_date.nil?

      count = [count.to_i, 1].max
      cursor = start_date
      worked = 0

      MAX_SCAN_DAYS.times do
        worked += 1 unless non_working?(cursor, holidays: holidays, week_days: week_days)
        return cursor if worked >= count
        cursor += 1
      end

      cursor
    end
  end
end
