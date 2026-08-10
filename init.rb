#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Redmine::Plugin.register :redmine_qbo_calendar do
  
  # About
  name 'Redmine QBO Calendar plugin'
  author 'Rick Barrette'
  description 'A plugin for Redmine to extend the capabilitys of the Redmine QuickBooks Online plugin to create customer appointments for the Redmine Calendar'
  version '2026.8.0'
  url 'https://github.com/rickbarrette/redmine_qbo_calendar'
  author_url 'https://barrettefabrication.com'
  requires_redmine version_or_higher: '7.0.0'
  settings partial: 'calendar/settings'

  # Ensure redmine_qbo is installed
  begin
    requires_redmine_plugin :redmine_qbo, version_or_higher: '2026.8.0'
  rescue Redmine::PluginNotFound
    raise 'Please install the redmine_qbo plugin (https://github.com/rickbarrette/redmine_qbo)'
  end

  project_module :customer_calendar do
    permission :view_customer_appointments,
              { customer_appointments: [:index, :show] }

    permission :manage_customer_appointments,
              {
                customer_appointments: [
                  :new,
                  :create,
                  :edit,
                  :update,
                  :destroy
                ]
              }
end

  menu :project_menu,
       :customer_calendar,
       { controller: 'events',
         action: 'index' },
       caption: 'Customer Calendar',
       after: :calendar,
       param: :project_id
end

Rails.configuration.to_prepare do
  ApplicationController.prepend_view_path( File.expand_path("app/views", __dir__) )

  Redmine::Views::MyPage::Block.register(
      'upcoming_appointments',
      label: :label_upcoming_appointments,
      partial: 'my/blocks/upcoming_appointments'
    )
end

RedmineQboCalendar.setup