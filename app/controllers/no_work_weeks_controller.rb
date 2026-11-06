# The MIT License (MIT)
#
# Copyright (c) 2026 rick barrette
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Flags and unflags a calendar week as "no new work" (the checkbox at the start of each calendar week)
class NoWorkWeeksController < ApplicationController
  before_action :require_login
  before_action :authorize_global

  def update
    date = Date.parse(params[:week].to_s)
    if params[:flagged] == '1'
      NoWorkWeek.flag!(date)
    else
      NoWorkWeek.unflag!(date)
    end

    respond_to do |format|
      format.html { redirect_back_or_default issues_calendar_path }
      format.json { render json: { week_start: NoWorkWeek.week_start_for(date), flagged: params[:flagged] == '1' } }
    end
  rescue Date::Error
    render_error status: 422, message: l(:error_invalid_no_work_week)
  end
end
