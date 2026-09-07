# Redmine QuickBooks Calendar

A plugin for Redmine that extends the functionality of the [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) plugin.

This plugin allows for adding customer appointment capability to the Redmine calendar.

---

## Requirements

*   **Redmine:** 6.1+
    
*   **Parent Plugin:** [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) (must be installed and configured)
    
---

## Compatibility

| Plugin Version | Redmine Version | Parent Plugin Version |
| --- | --- | --- |
| 2026.8.0+ | 7.0.x | 2026.8.0+ |

---

## Features

Add appointments to the redmine calanedar with the abiltiy to attach a QBO customer, QBO Vehicle, QBO Estimate, ect.

---

## Installation

1.  **Clone the plugin**
    

Navigate to your Redmine plugins directory:

```bash
cd /path/to/redmine/plugins  
git clone https://github.com/rickbarrette/redmine_qbo_calendar.git  
cd redmine_qbo_calendar  
  
# Optional: checkout a specific version  
git checkout <tag>
```


2.  **Install dependencies**
    
```bash
bundle install
```

3.  **Migrate your database**
    
```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

4.  **Restart Redmine**
    

Restart your application server (Puma, Passenger, etc.) to initialize the plugin hooks.

---

## Usage

1. Managing Customer Appointments
    * Viewing the Calendar: Navigate to the Customer Calendar tab within a project or via the top menu to view scheduled customer appointments.
    * Adding Appointments: Click on available days on the calendar grid to schedule a new appointment (restricted by user permissions, working days, and configured holidays).
    * Editing & Deleting: Existing appointments can be modified or removed directly from the calendar interface depending on user privileges.
    * My Page Integration: Users can add the Upcoming Appointments block to their personal My Page dashboard to track their schedule at a glance.

2. Holidays and Non-Working Days
Administrators can manage the holiday calendar to prevent appointments from being scheduled on non-working days.
    * Go to Administration -> Holidays (or the corresponding holidays menu item).
    * Fixed Holidays: Set specific dates (e.g., December 25th) that recur annually or apply to a single year.
    * Dynamic Holidays: Configure rules for floating holidays (e.g., the 1st Monday of September).
    * Validation: The system automatically blocks appointment creation on standard weekends, non-working days, and defined holidays.

3. Permissions & Global Access
Appointment permissions are configured globally to apply system-wide:
    1. Navigate to Administration -> Roles and permissions.
    2.  Scroll to the global permissions section.
    3.  Assign the following permissions as needed based on user roles (such as Non-member or custom staff roles):
        * View customer appointments
        * Add customer appointments
        * Edit customer appointments
        * Delete customer appointments

---

## License

> The MIT License (MIT)
> 
> Copyright (c) 2026 Rick Barrette
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
