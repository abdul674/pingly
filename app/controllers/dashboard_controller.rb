class DashboardController < ApplicationController
  def index
    @categories = Category.includes(:messages).all
    @messages = Message.includes(:source, :categories).active.recent.limit(50)
    @unread_count = Message.unread.count
    @connections = PlatformConnection.active
  end
end
