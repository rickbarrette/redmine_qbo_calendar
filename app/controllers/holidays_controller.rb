#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO CustomerAppointment SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class HolidaysController < ApplicationController
  layout 'admin' # Uses Redmine's admin layout to fit standard administration menus

  before_action :require_admin # Adjust permissions if regular project managers should access this
  before_action :find_holiday, only: [:edit, :update, :destroy]

  def index
    @holidays = Holiday.order(exact_date: :asc, month: :asc)
  end

  def new
    @holiday = Holiday.new
  end

  def create
    @holiday = Holiday.new(holiday_params)
    
    if @holiday.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to holidays_path
    else
      respond_to do |format|
        format.html { render action: 'new' }
      end
    end
  end

  def edit
    # @holiday is loaded via before_action
  end

  def update
    if @holiday.update(holiday_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to holidays_path
    else
      respond_to do |format|
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @holiday.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to holidays_path
  rescue ActiveRecord::DeleteRestrictionError
    flash[:error] = l(:notice_unable_delete_holiday)
    redirect_to holidays_path
  end

  private

  def find_holiday
    @holiday = Holiday.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def holiday_params
    params.require(:holiday).permit(
      :name, 
      :exact_date, 
      :is_recurring, 
      :recurrence_type, 
      :month, 
      :day_of_week, 
      :week_of_month
    )
  end
end