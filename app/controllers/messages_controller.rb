class MessagesController < ApplicationController
  before_action :set_message, only: [ :show, :mark_read, :mark_done, :snooze, :unsnooze ]

  def index
    @messages = Message.includes(:source, :categories).recent

    @messages = @messages.where(status: params[:status]) if params[:status].present?
    @messages = @messages.where(source_id: params[:source_id]) if params[:source_id].present?

    if params[:category_id].present?
      @messages = @messages.joins(:message_categories)
                           .where(message_categories: { category_id: params[:category_id] })
    end

    @messages = @messages.limit(50)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @message.mark_read! if @message.status == "unread"
  end

  def mark_read
    @message.mark_read!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@message, partial: "messages/message_card", locals: { message: @message }) }
      format.html { redirect_back fallback_location: messages_path }
    end
  end

  def mark_done
    @message.mark_done!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@message) }
      format.html { redirect_back fallback_location: messages_path }
    end
  end

  def snooze
    duration = params[:duration] || "1_hour"
    until_time = case duration
    when "30_min" then 30.minutes.from_now
    when "1_hour" then 1.hour.from_now
    when "3_hours" then 3.hours.from_now
    when "tomorrow" then 1.day.from_now.beginning_of_day + 9.hours
    when "next_week" then 1.week.from_now.beginning_of_day + 9.hours
    else 1.hour.from_now
    end

    @message.snooze!(until_time)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@message) }
      format.html { redirect_back fallback_location: messages_path }
    end
  end

  def unsnooze
    @message.unsnooze!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@message, partial: "messages/message_card", locals: { message: @message }) }
      format.html { redirect_back fallback_location: messages_path }
    end
  end

  private

  def set_message
    @message = Message.find(params[:id])
  end
end
