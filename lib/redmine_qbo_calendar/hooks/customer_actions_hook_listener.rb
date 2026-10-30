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
  module Hooks

    class CustomerActionsHookListener < Redmine::Hook::ViewListener

      # Adds "Add appointment" to the customer page's top-right action area
      # (redmine_qbo's :view_customers_show_contextual hook).
      def view_customers_show_contextual(context = {})
        context[:hook_caller].render(partial: 'customer_appointments/customer_actions',
                                     locals: { customer: context[:customer] })
      end

      # Adds "Add appointment" to an estimate's page in redmine_qbo_billing (:view_qbo_estimate_contextual),
      # with the customer, the estimate and the vehicle matching its VIN filled in
      def view_qbo_estimate_contextual(context = {})
        customer = Customer.find_by(id: context[:customer_id])
        return '' unless customer

        context[:hook_caller].render(partial: 'customer_appointments/estimate_actions',
                                     locals: { customer: customer, estimate_id: context[:estimate_id], vin: context[:vin] })
      end
      
    end
  end
end