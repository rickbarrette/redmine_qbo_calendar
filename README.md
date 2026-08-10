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

## Configuration

This plugin depends on the **Redmine QuickBooks Online** plugin.

Before using this plugin:

1.  Install and configure the parent plugin.
    
2.  Ensure your **QuickBooks Online** company file is connected.

3.  Sync Accounts & Items via plugin settings

4.  Set default income account for new items via plugin settings

---

## Usage

Add appointments
    

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
