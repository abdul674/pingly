module Providers
  class Base
    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def fetch_messages(since: nil)
      raise NotImplementedError
    end

    def normalize(raw_event)
      raise NotImplementedError
    end

    def deep_link(msg)
      raise NotImplementedError
    end

    def sync_sources
      raise NotImplementedError
    end
  end
end
