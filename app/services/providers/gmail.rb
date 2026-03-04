module Providers
  class Gmail < Base
    SKIP_LABELS = %w[SENT DRAFT TRASH SPAM CHAT UNREAD STARRED IMPORTANT
                     CATEGORY_FORUMS CATEGORY_PROMOTIONS CATEGORY_SOCIAL].freeze

    LABEL_SOURCE_TYPES = {
      "INBOX" => "inbox",
      "STARRED" => "label",
      "IMPORTANT" => "label",
      "CATEGORY_PERSONAL" => "label",
      "CATEGORY_UPDATES" => "label"
    }.freeze

    def client
      @client ||= begin
        auth_client = GoogleAuth::Client.new(connection)
        auth_client.ensure_valid_token!

        service = Google::Apis::GmailV1::GmailService.new
        service.authorization = google_authorization
        service
      end
    end

    def sync_sources
      response = client.list_user_labels("me")
      return unless response.labels

      response.labels.each do |label|
        next if SKIP_LABELS.include?(label.id)

        source_type = LABEL_SOURCE_TYPES[label.id] || "label"

        connection.sources.find_or_initialize_by(external_id: label.id).tap do |source|
          source.name = label.name
          source.source_type = source_type
          source.metadata = { label_type: label.type }
          source.save!
        end
      end
    end

    def fetch_messages(since: nil)
      connection.sources.monitored.find_each do |source|
        history_id = source.metadata&.dig("last_history_id")

        if history_id.present?
          fetch_via_history(source, history_id)
        else
          fetch_via_list(source, since)
        end
      rescue Google::Apis::ClientError => e
        Rails.logger.warn "Gmail: error fetching messages for source #{source.external_id}: #{e.message}"
      end
    end

    def normalize(raw_message, source: nil)
      headers = raw_message.payload&.headers || []
      from = header_value(headers, "From")
      subject = header_value(headers, "Subject")

      sender_name = parse_sender_name(from)
      content = [ subject, raw_message.snippet ].compact.join("\n")

      {
        source: source,
        external_id: raw_message.id,
        sender_name: sender_name,
        sender_avatar: nil,
        content: content,
        mentioned: false,
        deep_link: deep_link_url(raw_message.id),
        raw_data: { id: raw_message.id, from: from, subject: subject, snippet: raw_message.snippet },
        received_at: Time.at(raw_message.internal_date.to_i / 1000)
      }
    end

    def deep_link(msg)
      deep_link_url(msg.external_id)
    end

    private

    def google_authorization
      creds = connection.credentials
      auth = Signet::OAuth2::Client.new(
        access_token: creds["access_token"],
        expires_at: creds["expires_at"] ? Time.at(creds["expires_at"].to_i) : nil
      )
      auth
    end

    def fetch_via_history(source, history_id)
      response = client.list_user_histories("me",
        start_history_id: history_id,
        history_types: "messageAdded",
        label_id: source.external_id
      )

      new_history_id = response.history_id
      update_history_id(source, new_history_id)

      return unless response.history

      message_ids = response.history.flat_map do |h|
        (h.messages_added || []).map { |ma| ma.message.id }
      end.uniq

      message_ids.each do |msg_id|
        raw = client.get_user_message("me", msg_id,
          format: "metadata",
          metadata_headers: [ "From", "Subject", "Date" ]
        )
        normalized = normalize(raw, source: source)
        MessageProcessor.new.process(normalized)
      end
    rescue Google::Apis::ClientError => e
      if e.message.include?("404") || e.message.include?("historyId")
        Rails.logger.info "Gmail: history expired for source #{source.external_id}, falling back to list"
        fetch_via_list(source, 5.minutes.ago)
      else
        raise
      end
    end

    def fetch_via_list(source, since)
      timestamp = (since || 5.minutes.ago).to_i
      query = "after:#{timestamp}"
      query += " label:#{source.external_id}" unless source.external_id == "INBOX"

      response = client.list_user_messages("me", q: query, label_ids: [ source.external_id ], max_results: 100)
      return unless response.messages

      latest_history_id = nil

      response.messages.each do |msg_ref|
        next if source.messages.exists?(external_id: msg_ref.id)

        raw = client.get_user_message("me", msg_ref.id,
          format: "metadata",
          metadata_headers: [ "From", "Subject", "Date" ]
        )

        latest_history_id = raw.history_id if latest_history_id.nil? || raw.history_id.to_i > latest_history_id.to_i

        normalized = normalize(raw, source: source)
        MessageProcessor.new.process(normalized)
      end

      update_history_id(source, latest_history_id) if latest_history_id
    end

    def update_history_id(source, history_id)
      return unless history_id
      source.update!(metadata: (source.metadata || {}).merge("last_history_id" => history_id.to_s))
    end

    def header_value(headers, name)
      headers.find { |h| h.name == name }&.value
    end

    def parse_sender_name(from)
      return "Unknown" if from.blank?

      if from =~ /\A"?(.+?)"?\s*<.+>\z/
        $1.strip
      else
        from.split("@").first
      end
    end

    def deep_link_url(message_id)
      "https://mail.google.com/mail/u/0/#inbox/#{message_id}"
    end
  end
end
