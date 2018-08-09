# frozen_string_literal: true

module Sniffer
  module Adapters
    # HttpClient adapter
    module HTTPClientAdapter
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def do_get_block(req, proxy, conn, &block)
        return super(req, proxy, conn, &block) unless Sniffer.enabled?

        data_item = Sniffer::DataItem.new
        data_item.request = Sniffer::DataItem::Request.new(host: req.header.request_uri.host,
                                                           query: req.header.create_query_uri,
                                                           method: req.header.request_method,
                                                           headers: req.headers,
                                                           body: req.body,
                                                           port: req.header.request_uri.port)

        Sniffer.store(data_item)

        retryable_response = nil

        bm = Benchmark.realtime do
          begin
            super(req, proxy, conn, &block)
          rescue HTTPClient::RetryableResponse => e
            retryable_response = e
          end
        end

        res = conn.pop
        data_item.response = Sniffer::DataItem::Response.new(status: res.status_code.to_i,
                                                             headers: res.headers,
                                                             body: res.body,
                                                             timing: bm)

        conn.push(res)

        data_item.log

        raise retryable_response unless retryable_response.nil?
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end

HTTPClient.send(:prepend, Sniffer::Adapters::HTTPClientAdapter) if defined?(::HTTPClient)
