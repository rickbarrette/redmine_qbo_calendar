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

class AppointmentStatusTest < ActiveSupport::TestCase
  include QboCalendarTestHelper

  Status = RedmineQboCalendar::AppointmentStatus

  def test_the_defaults
    assert_equal %w[Scheduled Checked_In In_Progress Ready Completed Cancelled], Status.all.map(&:key)
    assert_equal 'Scheduled', Status.default.key
    assert_not Status.find('Cancelled').counts_hours?
    assert Status.find('Ready').counts_hours?
    assert_equal '--status-color: #1fc0ff', Status.default.style
    assert_equal 'Checked in', Status.find('Checked_In').to_s
  end

  def test_statuses_from_the_settings
    with_calendar_settings('statuses' => { '0' => { 'key' => '', 'name' => 'Booked', 'color' => '#00FF00', 'counts_hours' => '1' },
                                           '1' => { 'key' => 'Gone', 'name' => 'No show', 'color' => 'red', 'counts_hours' => '0' },
                                           '2' => { 'name' => ' ' } }) do
      statuses = Status.all
      assert_equal %w[Booked Gone], statuses.map(&:key)
      assert_equal '#00ff00', statuses.first.color
      assert_equal Status::UNKNOWN_COLOR, statuses.last.color
      assert_not statuses.last.counts_hours?
      assert_equal [['Booked', 'Booked'], ['No show', 'Gone']], CustomerAppointment.status_options
    end
  end

  def test_no_usable_statuses_means_the_defaults
    with_calendar_settings('statuses' => [{ 'name' => '' }]) { assert_equal 6, Status.all.size }
    with_calendar_settings(statuses: [{ 'name' => 'Booked' }]) { assert_equal ['Booked'], Status.all.map(&:key) }
  end

  def test_normalize_makes_unique_keys
    rows = Status.normalize([{ 'name' => 'Waiting on parts!' }, { 'name' => 'Waiting on parts' }, { 'name' => '***' }])
    assert_equal %w[Waiting_on_parts Waiting_on_parts_2 Status], rows.map { |r| r['key'] }
  end

  def test_a_removed_status_still_shows
    status = Status.find('On_Hold')
    assert_equal 'On hold', status.name
    assert_equal Status::UNKNOWN_COLOR, status.color
    assert_not status.known?
    assert_nil Status.find('')
  end

  def test_moving_appointments_off_a_removed_status
    on_hold = create_appointment(status: 'On_Hold')
    call_out = create_call_out
    call_out.update_columns(status: 'On_Hold')
    moved = Status.move_appointments({ 'On_Hold' => 'Ready', 'Scheduled' => 'Ready', 'Gone' => 'Nope' }, names: { 'On_Hold' => 'On hold' })
    assert_equal [{ count: 1, from: 'On hold', to: 'Ready' }], moved
    assert_equal 'Ready', on_hold.reload.status
    # Call-outs have no status, so they're left alone
    assert_equal 'On_Hold', call_out.reload.status
  end
end
