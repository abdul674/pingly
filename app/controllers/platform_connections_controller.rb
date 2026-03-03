class PlatformConnectionsController < ApplicationController
  before_action :set_connection, only: [ :show, :edit, :update, :destroy, :toggle ]

  def index
    @connections = PlatformConnection.all
  end

  def show
    @sources = @connection.sources.roots.order(:name)
  end

  def new
    @connection = PlatformConnection.new(platform: "slack", connection_method: "manual")
  end

  def create
    @connection = PlatformConnection.new(connection_params)
    @connection.credentials = { "bot_token" => params[:bot_token] } if params[:bot_token].present?

    if @connection.save
      SlackSyncSourcesJob.perform_later(@connection.id) if @connection.platform == "slack"
      redirect_to platform_connection_path(@connection), notice: "Connection created. Syncing channels..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @connection.credentials = { "bot_token" => params[:bot_token] } if params[:bot_token].present?

    if @connection.update(connection_params)
      redirect_to platform_connection_path(@connection), notice: "Connection updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @connection.destroy
    redirect_to platform_connections_path, notice: "Connection removed."
  end

  def toggle
    @connection.update!(active: !@connection.active)
    redirect_to platform_connections_path, notice: "Connection #{@connection.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_connection
    @connection = PlatformConnection.find(params[:id])
  end

  def connection_params
    params.require(:platform_connection).permit(:platform, :workspace_name, :connection_method)
  end
end
