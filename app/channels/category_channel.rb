class CategoryChannel < ApplicationCable::Channel
  def subscribed
    stream_from "category_#{params[:id]}"
  end
end
