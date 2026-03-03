module Providers
  class Slack < Base
    def client
      @client ||= ::Slack::Web::Client.new(token: connection.bot_token)
    end

    def fetch_messages(since: nil)
      connection.sources.monitored.find_each do |source|
        opts = { channel: source.external_id, limit: 100 }
        opts[:oldest] = since.to_f.to_s if since

        response = client.conversations_history(**opts)
        next unless response["ok"]

        bot_user_id = auth_info["user_id"]

        response["messages"].each do |raw|
          next if raw["subtype"].present? && raw["subtype"] != "bot_message"

          normalized = normalize(raw, source: source, bot_user_id: bot_user_id)
          MessageProcessor.new.process(normalized)
        end
      rescue ::Slack::Web::Api::Errors::ChannelNotFound,
             ::Slack::Web::Api::Errors::NotInChannel
        Rails.logger.warn "Slack: cannot access channel #{source.external_id}"
      end
    end

    def normalize(raw, source: nil, bot_user_id: nil)
      sender = resolve_user(raw["user"]) if raw["user"]
      mentioned = bot_user_id && raw["text"]&.include?("<@#{bot_user_id}>")

      {
        source: source,
        external_id: raw["ts"],
        sender_name: sender&.dig("real_name") || sender&.dig("name") || "Unknown",
        sender_avatar: sender&.dig("profile", "image_48"),
        content: raw["text"],
        mentioned: mentioned || false,
        deep_link: deep_link_for(source, raw["ts"]),
        raw_data: raw,
        received_at: Time.at(raw["ts"].to_f)
      }
    end

    def deep_link(msg)
      deep_link_for(msg.source, msg.external_id)
    end

    def sync_sources
      response = client.conversations_list(
        types: "public_channel,private_channel,mpim,im",
        limit: 1000
      )
      return unless response["ok"]

      response["channels"].each do |channel|
        connection.sources.find_or_initialize_by(external_id: channel["id"]).tap do |source|
          source.name = channel["name"] || channel["user"]
          source.source_type = channel_type(channel)
          source.metadata = {
            is_member: channel["is_member"],
            is_private: channel["is_private"],
            num_members: channel["num_members"]
          }
          source.save!
        end
      end
    end

    def resolve_user(user_id)
      return nil if user_id.blank?

      Rails.cache.fetch("slack_user/#{connection.id}/#{user_id}", expires_in: 1.hour) do
        response = client.users_info(user: user_id)
        response["user"] if response["ok"]
      rescue ::Slack::Web::Api::Errors::UserNotFound
        nil
      end
    end

    private

    def auth_info
      @auth_info ||= Rails.cache.fetch("slack_auth/#{connection.id}", expires_in: 1.hour) do
        client.auth_test
      end
    end

    def deep_link_for(source, ts)
      return nil unless source && ts

      workspace = connection.workspace_name || auth_info["url"]&.gsub(%r{https://|\.slack\.com/}, "")
      timestamp = ts.to_s.delete(".")
      "https://#{workspace}.slack.com/archives/#{source.external_id}/p#{timestamp}"
    end

    def channel_type(channel)
      if channel["is_im"]
        "dm"
      elsif channel["is_mpim"]
        "group_dm"
      elsif channel["is_private"]
        "private_channel"
      else
        "channel"
      end
    end
  end
end
