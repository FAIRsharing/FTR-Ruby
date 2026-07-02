# frozen_string_literal: true

require "spec_helper"

RSpec.describe FtrRuby::Tests do
  describe ".register_test" do
    let(:test_uri) { "https://example.org/tests/ftr-test-001.ttl" }
    let(:proxy_url) { "https://proxy.example.org/register" }

    it "posts the test URI to the proxy and returns the response body" do
      response = instance_double(RestClient::Response, body: "registered")
      allow(RestClient::Request).to receive(:execute).and_return(response)
      allow(described_class).to receive(:warn)

      result = described_class.register_test(test_uri: test_uri, proxy_url: proxy_url)

      expect(result).to eq("registered")
      expect(RestClient::Request).to have_received(:execute).with(
        hash_including(
          method: :post,
          url: proxy_url,
          headers: {
            "Accept" => "application/json",
            "Content-Type" => "application/json"
          },
          payload: { "clientUrl": test_uri }.to_json
        )
      )
    end

    it "warns and returns nil when registration fails before a response is assigned" do
      allow(RestClient::Request).to receive(:execute).and_raise(StandardError, "proxy unavailable")

      expect do
        expect(described_class.register_test(test_uri: test_uri, proxy_url: proxy_url)).to be_nil
      end.to output(/registering new test.*response is nil error #<StandardError: proxy unavailable>/m).to_stderr
    end
  end
end
