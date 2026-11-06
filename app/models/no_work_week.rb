# The MIT License (MIT)
#
# Copyright (c) 2026 rick barrette
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# A week flagged "no new work" on the calendar. Weeks are keyed by their Monday, so the flag holds whatever
# day the user's calendar starts its rows on.
class NoWorkWeek < ApplicationRecord
  belongs_to :user, optional: true

  validates :week_start, presence: true, uniqueness: true

  # The Monday of the week a date is in
  def self.week_start_for(date)
    date.to_date.beginning_of_week(:monday)
  end

  # The Mondays of the flagged weeks among the given dates' weeks, read in one query
  def self.flagged_week_starts(dates)
    starts = Array(dates).compact.map { |d| week_start_for(d) }.uniq
    return Set.new if starts.empty?

    where(week_start: starts).pluck(:week_start).to_set
  end

  # Whether any of the dates falls in a flagged week
  def self.flagged?(*dates)
    flagged_week_starts(dates.flatten).any?
  end

  def self.flag!(date, user = User.current)
    find_or_create_by!(week_start: week_start_for(date)) { |w| w.user = user if user&.logged? }
  rescue ActiveRecord::RecordNotUnique
    find_by(week_start: week_start_for(date))
  end

  def self.unflag!(date)
    where(week_start: week_start_for(date)).delete_all
  end
end
