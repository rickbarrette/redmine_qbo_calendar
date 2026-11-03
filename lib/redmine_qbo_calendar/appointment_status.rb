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
  # An appointment status, set up in the plugin settings (name, colour, whether its time counts toward the
  # calendar's hours). Appointments store the status's key, which never changes, so renaming a status
  # keeps its appointments. The first status is the default for new appointments.
  class AppointmentStatus
    # The statuses before they could be set up (an appointment's key is the status it was saved with)
    DEFAULTS = [
      { 'key' => 'Scheduled',   'name' => 'Scheduled',   'color' => '#1fc0ff', 'counts_hours' => '1' },
      { 'key' => 'Checked_In',  'name' => 'Checked in',  'color' => '#ce1fff', 'counts_hours' => '1' },
      { 'key' => 'In_Progress', 'name' => 'In progress', 'color' => '#ff5e1f', 'counts_hours' => '1' },
      { 'key' => 'Ready',       'name' => 'Ready',       'color' => '#1fff1f', 'counts_hours' => '1' },
      { 'key' => 'Completed',   'name' => 'Completed',   'color' => '#008000', 'counts_hours' => '1' },
      { 'key' => 'Cancelled',   'name' => 'Cancelled',   'color' => '#ff1f1f', 'counts_hours' => '0' }
    ].freeze

    # Appointments whose status was removed from the settings
    UNKNOWN_COLOR = '#8d9096'

    attr_reader :key, :name, :color

    def initialize(key:, name:, color:, counts_hours: true, known: true)
      @key = key
      @name = name
      @color = color
      @counts_hours = counts_hours
      @known = known
    end

    # False for statuses like Cancelled: the appointment stays on the calendar but frees up its hours
    def counts_hours?
      @counts_hours
    end

    # False when the status was removed from the settings after appointments used it
    def known?
      @known
    end

    # Sets the colour for the status's badge or calendar block (see customer_appointments.css)
    def style
      "--status-color: #{color}"
    end

    def to_s
      name
    end

    def self.all
      settings = Setting.plugin_redmine_qbo_calendar || {}
      raw = settings['statuses'] || settings[:statuses]
      statuses = normalize(raw.presence || DEFAULTS)
      statuses = normalize(DEFAULTS) if statuses.empty?
      statuses.map do |s|
        new(key: s['key'], name: s['name'], color: s['color'], counts_hours: s['counts_hours'] == '1')
      end
    end

    def self.default
      all.first
    end

    # The status with this key; a removed status keeps showing (grey, with its key as the name)
    def self.find(key)
      return nil if key.blank?
      all.detect { |s| s.key == key.to_s } ||
        new(key: key.to_s, name: key.to_s.humanize, color: UNKNOWN_COLOR, known: false)
    end

    # Moves the appointments of removed statuses ({ removed key => new key }), once the settings are saved.
    # Skipped when the old status is still set up or the new one isn't. Returns what was moved, for the notice
    # (names: the statuses' names before saving).
    def self.move_appointments(moves, names: {})
      statuses = all.index_by(&:key)
      moves.filter_map do |from, to|
        next if statuses.key?(from) || !statuses.key?(to)

        count = CustomerAppointment.where(status: from, event_type: [nil, '']).update_all(status: to)
        Rails.logger.info "[AppointmentStatus] Moved #{count} appointment(s) from #{from} to #{to}"
        { count: count, from: names[from] || from.humanize, to: statuses[to].name } if count.positive?
      end
    end

    # The settings form's rows (a hash by row index, in the order shown, or a list) as a clean list:
    # rows without a name are dropped, a new row's key comes from its name, and keys are unique
    def self.normalize(raw)
      rows = raw.is_a?(Hash) ? raw.values : Array(raw)
      keys = []
      rows.filter_map do |row|
        row = row.to_h.stringify_keys
        name = row['name'].to_s.strip
        next if name.empty?

        key = row['key'].to_s.strip.presence || name.gsub(/[^[:alnum:]]+/, '_').gsub(/\A_+|_+\z/, '').presence || 'Status'
        base = key
        number = 1
        key = "#{base}_#{number += 1}" while keys.include?(key)
        keys << key
        color = row['color'].to_s.strip
        color = UNKNOWN_COLOR unless color.match?(/\A#\h{6}\z/)
        { 'key' => key, 'name' => name, 'color' => color.downcase, 'counts_hours' => row['counts_hours'].to_s == '1' ? '1' : '0' }
      end
    end
  end
end
