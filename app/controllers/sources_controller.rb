class SourcesController < ApplicationController
  before_action :set_connection

  def index
    @sources = @connection.sources.roots.includes(:children).order(:name)
  end

  def toggle_monitor
    @source = @connection.sources.find(params[:id])
    @source.update!(monitored: !@source.monitored)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@source),
          partial: "sources/source_row",
          locals: { source: @source }
        )
      end
      format.html { redirect_to platform_connection_sources_path(@connection) }
    end
  end

  private

  def set_connection
    @connection = PlatformConnection.find(params[:platform_connection_id])
  end
end
