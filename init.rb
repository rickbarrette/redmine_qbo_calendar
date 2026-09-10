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
  version '2026.9.2'
  url 'https://github.com/rickbarrette/redmine_qbo_calendar'
  author_url 'https://barrettefabrication.com'
  requires_redmine version_or_higher: '7.0.0'

  # Add Holidays index to the Redmine Administration Menu
  menu :admin_menu, :holidays, { controller: 'holidays', action: 'index' }, caption: :label_holiday_plural, html: { class: 'icon icon-list' }

  # Ensure redmine_qbo is installed
  begin
    requires_redmine_plugin :redmine_qbo, version_or_higher: '2026.8.2'
  rescue Redmine::PluginNotFound
    raise 'Please install the redmine_qbo plugin (https://github.com/rickbarrette/redmine_qbo)'
  end

  # Global Permissions
  permission :view_customer_appointments, { customer_appointments: [:index, :show] }, global: true
  permission :add_customer_appointments, { customer_appointments: [:new, :create] }, global: true
  permission :edit_customer_appointments, { customer_appointments: [:edit, :update] }, global: true
  permission :delete_customer_appointments, { customer_appointments: [:destroy] }, global: true

  # Register top menu items
  menu :top_menu, :calendar, { controller: :calendars, action: :show }, caption: :label_calendar, if: Proc.new {User.current.logged?}
  
end

RedmineQboCalendar.setup