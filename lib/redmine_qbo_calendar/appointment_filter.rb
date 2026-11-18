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
  # Applies the calendar's issue filters that mean something for appointments, so filtering the calendar by
  # assignee (for example) narrows its appointments too:
  #
  # * Assignee: the appointment's technician (and a call-out's employee). "Me" is the current user, a group
  #   stands for its members.
  # * Customer (redmine_qbo's customer name filter): the appointment's customer. "Doesn't contain" keeps
  #   call-outs, which have no customer.
  # * Project: the appointment's project ("My projects" and "My bookmarks" as for issues).
  #
  # The other filters (status, tracker, priority...) are about issues, so they leave appointments alone.
  class AppointmentFilter
    FIELDS = %w[assigned_to_id customer_name project_id].freeze

    def initialize(query, user: User.current)
      @query = query
      @user = user
    end

    # The filters that apply to appointments, e.g. ["assigned_to_id"]
    def applied_fields
      return [] unless @query

      FIELDS.select { |field| @query.has_filter?(field) }
    end

    def apply(scope)
      applied_fields.reduce(scope) do |filtered, field|
        operator = @query.operator_for(field)
        values = Array(@query.values_for(field)).map(&:to_s)
        send("filter_#{field}", filtered, operator, values) || filtered
      end
    end

    private

    def filter_assigned_to_id(scope, operator, values)
      column = CustomerAppointment.arel_table[:user_id]
      case operator
      when '='  then scope.where(user_id: user_ids(values))
      when '!'  then scope.where(column.not_in(user_ids(values)).or(column.eq(nil)))
      when '*'  then scope.where.not(user_id: nil)
      when '!*' then scope.where(user_id: nil)
      end
    end

    def filter_customer_name(scope, operator, values)
      pattern = "%#{CustomerAppointment.sanitize_sql_like(values.first.to_s)}%"
      case operator
      when '~'  then scope.joins(:customer).where("#{Customer.table_name}.name LIKE ?", pattern)
      when '!~' then scope.left_joins(:customer)
                          .where("#{Customer.table_name}.name NOT LIKE ? OR #{Customer.table_name}.id IS NULL", pattern)
      end
    end

    def filter_project_id(scope, operator, values)
      column = CustomerAppointment.arel_table[:project_id]
      case operator
      when '='  then scope.where(project_id: project_ids(values))
      when '!'  then scope.where(column.not_in(project_ids(values)).or(column.eq(nil)))
      when '*'  then scope.where.not(project_id: nil)
      when '!*' then scope.where(project_id: nil)
      end
    end

    # User ids for the filter's values: "me" is the current user; a group is its members
    def user_ids(values)
      ids = values.map { |v| v == 'me' ? (@user.logged? ? @user.id : 0) : v.to_i }
      groups = Group.where(id: ids).includes(:users).to_a
      (ids - groups.map(&:id) + groups.flat_map(&:user_ids)).uniq
    end

    def project_ids(values)
      values.flat_map do |v|
        case v
        when 'mine' then @user.memberships.pluck(:project_id)
        when 'bookmarks' then @user.bookmarked_project_ids.map(&:to_i)
        else [v.to_i]
        end
      end.uniq
    end
  end
end
