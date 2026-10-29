#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Records which issue was created from which QBO estimate line, so a line can't be turned into
# an issue twice (even from a different appointment that uses the same estimate).
class CreateAppointmentEstimateIssues < ActiveRecord::Migration[7.0]
  def change
    create_table :appointment_estimate_issues do |t|
      t.references :customer_appointment, index: true
      t.bigint :estimate_id, null: false
      t.string :line_id, null: false
      t.references :issue, null: false, index: { unique: true }
      t.datetime :created_on, null: false
    end

    add_index :appointment_estimate_issues, [:estimate_id, :line_id], unique: true, name: 'index_appointment_estimate_issues_on_line'
  end
end
