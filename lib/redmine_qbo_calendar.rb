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
  DEFAULT_HOURS_PER_DAY = 8.0

  # A working day's hours (plugin setting): multi-day appointments use up to this many hours a day on the
  # calendar, and one without its own hours takes this many a day
  def self.hours_per_day
    hours = (Setting.plugin_redmine_qbo_calendar || {})['hours_per_day'].to_f
    hours.positive? && hours <= 24 ? hours : DEFAULT_HOURS_PER_DAY
  end

  def self.setup
    # Patches
    Customer.prepend(RedmineQboCalendar::Patches::CustomerPatch)
    User.prepend(RedmineQboCalendar::Patches::UserPatch)
    Issue.prepend(RedmineQboCalendar::Patches::IssuePatch)
    CalendarsController.prepend(RedmineQboCalendar::Patches::CalendarsControllerPatch)
    SettingsController.prepend(RedmineQboCalendar::Patches::SettingsControllerPatch)
    ApplicationHelper.prepend(RedmineQboCalendar::Patches::ApplicationHelperPatch)

    # Hooks
    RedmineQboCalendar::Hooks::ViewHookListener
    RedmineQboCalendar::Hooks::CustomerActionsHookListener
    RedmineQboCalendar::Hooks::CustomerShowHookListener
    RedmineQboCalendar::Hooks::BillingHookListener

    Rails.configuration.to_prepare do
      ApplicationController.prepend_view_path( File.expand_path("app/views", __dir__) )

      Redmine::Views::MyPage::Block.register(
          'upcoming_appointments',
          label: :label_upcoming_appointments,
          partial: 'my/blocks/upcoming_appointments'
        )
    end
  end
end