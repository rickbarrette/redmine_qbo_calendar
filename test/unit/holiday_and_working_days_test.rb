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

class HolidayAndWorkingDaysTest < ActiveSupport::TestCase
  include QboCalendarTestHelper

  def test_a_one_off_holiday
    holiday = create_holiday
    assert holiday.occurs_on?(Date.new(2026, 11, 26))
    assert_not holiday.occurs_on?(Date.new(2027, 11, 26))
  end

  def test_a_fixed_holiday_every_year
    holiday = create_holiday('Christmas', exact_date: Date.new(2020, 12, 25), is_recurring: true, recurrence_type: 'fixed')
    assert holiday.occurs_on?(Date.new(2026, 12, 25))
    assert_not holiday.occurs_on?(Date.new(2026, 12, 24))
    holiday.exact_date = nil
    assert_not holiday.occurs_on?(Date.new(2026, 12, 25))
  end

  def test_the_nth_weekday_of_a_month
    # Thanksgiving: the 4th Thursday of November
    holiday = create_holiday(exact_date: nil, is_recurring: true, recurrence_type: 'dynamic', month: 11, day_of_week: 4,
                             week_of_month: 4)
    assert holiday.occurs_on?(Date.new(2026, 11, 26))
    assert holiday.occurs_on?(Date.new(2027, 11, 25))
    assert_not holiday.occurs_on?(Date.new(2026, 11, 19))
    assert_not holiday.occurs_on?(Date.new(2026, 10, 22))
  end

  def test_the_last_weekday_of_a_month
    # Memorial Day: the last Monday of May (week 4 in 2026, week 5 in 2027)
    holiday = create_holiday('Memorial Day', exact_date: nil, is_recurring: true, recurrence_type: 'dynamic', month: 5,
                             day_of_week: 1, week_of_month: Holiday::LAST_WEEK)
    assert holiday.occurs_on?(Date.new(2026, 5, 25))
    assert holiday.occurs_on?(Date.new(2027, 5, 31))
    assert_not holiday.occurs_on?(Date.new(2027, 5, 24))
  end

  def test_recurrence_types
    assert_not Holiday.new(name: 'X', recurrence_type: 'monthly').valid?
    assert Holiday.new(name: 'X', recurrence_type: '').valid?
    assert_not Holiday.new(is_recurring: true, recurrence_type: nil).occurs_on?(Date.new(2026, 11, 26))
  end

  def test_working_days_skip_weekends_and_holidays
    create_holiday
    # A 4-day job from Wednesday: Wed, (Thanksgiving), Fri, (weekend), Mon, Tue
    assert_equal [Date.new(2026, 11, 25), Date.new(2026, 11, 27), Date.new(2026, 11, 30), Date.new(2026, 12, 1)],
                 RedmineQboCalendar::WorkingDays.dates(Date.new(2026, 11, 25), 4)
    # Starting on a weekend: the first working day after it
    assert_equal [MONDAY], RedmineQboCalendar::WorkingDays.dates(Date.new(2026, 11, 21), 0)
    assert_equal [], RedmineQboCalendar::WorkingDays.dates(nil, 2)
  end

  def test_working_days_between
    create_holiday
    assert_equal [Date.new(2026, 11, 25), Date.new(2026, 11, 27), Date.new(2026, 11, 30)],
                 RedmineQboCalendar::WorkingDays.between(Date.new(2026, 11, 25), Date.new(2026, 11, 30))
    assert_equal [], RedmineQboCalendar::WorkingDays.between(Date.new(2026, 11, 30), Date.new(2026, 11, 25))
    assert_equal [], RedmineQboCalendar::WorkingDays.between(nil, Date.new(2026, 11, 25))
  end

  def test_hours_per_day
    assert_equal 8.0, RedmineQboCalendar.hours_per_day
    with_calendar_settings('hours_per_day' => '10') { assert_equal 10.0, RedmineQboCalendar.hours_per_day }
    with_calendar_settings('hours_per_day' => '25') { assert_equal 8.0, RedmineQboCalendar.hours_per_day }
    with_calendar_settings('hours_per_day' => 'x') { assert_equal 8.0, RedmineQboCalendar.hours_per_day }
  end

  def test_no_work_weeks
    assert_equal MONDAY, NoWorkWeek.week_start_for(Date.new(2026, 11, 29))
    week = NoWorkWeek.flag!(Date.new(2026, 11, 25), User.find(2))
    assert_equal MONDAY, week.week_start
    assert_equal 2, week.user_id
    assert_equal week, NoWorkWeek.flag!(MONDAY)
    assert_nil NoWorkWeek.flag!(Date.new(2026, 12, 1), User.anonymous).user_id

    assert_equal Set[MONDAY], NoWorkWeek.flagged_week_starts([Date.new(2026, 11, 24), Date.new(2026, 11, 20), nil])
    assert_equal Set.new, NoWorkWeek.flagged_week_starts([])

    NoWorkWeek.unflag!(Date.new(2026, 11, 27))
    assert_not NoWorkWeek.exists?(week_start: MONDAY)
  end
end
