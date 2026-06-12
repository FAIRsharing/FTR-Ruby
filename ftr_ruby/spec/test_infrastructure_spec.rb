# frozen_string_literal: true

require_relative './spec_helper'

RSpec.describe FtrRuby::TestInfra do
  subject(:infra) do
    described_class.new(
      test_host: 'localhost:8282',
      basepath: 'tests',
      test_protocol: 'http'
    )
  end

  def make_graph(title: nil, landing_page: nil)
    graph = RDF::Graph.new
    node = RDF::URI('https://example.org/metric/1')
    graph << [node, RDF::Vocab::DC.title, RDF::Literal.new(title)] if title
    graph << [node, RDF::Vocab::DCAT.landingPage, RDF::URI(landing_page)] if landing_page
    graph
  end

  describe '#get_tests_metrics' do
    let(:test_ids) { %w[test_a test_b test_c] }
    let(:metric_url) { 'https://example.org/metrics/some_metric' }
    let(:full_graph) { make_graph(title: 'My Metric', landing_page: 'https://example.org/lp') }

    before do
      allow(infra).to receive(:fetch_metric_url).and_return(metric_url)
      allow(infra).to receive(:load_metric_graph).and_return(full_graph)
    end

    it 'returns two hashes' do
      result = infra.get_tests_metrics(tests: test_ids)
      expect(result).to match([an_instance_of(Hash), an_instance_of(Hash)])
    end

    it 'has an entry for every test id in both hashes' do
      labels, lps = infra.get_tests_metrics(tests: test_ids)
      expect(labels.keys).to match_array(test_ids)
      expect(lps.keys).to match_array(test_ids)
    end

    it 'uses DC.title from the metric graph as the label' do
      labels, = infra.get_tests_metrics(tests: ['test_a'])
      expect(labels['test_a']).to eq('My Metric')
    end

    it 'uses DCAT.landingPage from the metric graph' do
      _, lps = infra.get_tests_metrics(tests: ['test_a'])
      expect(lps['test_a']).to eq('https://example.org/lp')
    end

    context 'when the metric graph has no title or landing page' do
      before { allow(infra).to receive(:load_metric_graph).and_return(RDF::Graph.new) }

      it 'falls back to "Metric label not available"' do
        labels, = infra.get_tests_metrics(tests: ['test_a'])
        expect(labels['test_a']).to eq('Metric label not available')
      end

      it 'returns an empty string for the landing page' do
        _, lps = infra.get_tests_metrics(tests: ['test_a'])
        expect(lps['test_a']).to eq('')
      end
    end

    context 'when RDF graph loading raises an error (load_metric_graph returns empty graph)' do
      before { allow(infra).to receive(:load_metric_graph).and_return(RDF::Graph.new) }

      it 'still returns an entry for the affected test id' do
        labels, = infra.get_tests_metrics(tests: ['test_a'])
        expect(labels).to have_key('test_a')
      end

      it 'uses the fallback label' do
        labels, = infra.get_tests_metrics(tests: ['test_a'])
        expect(labels['test_a']).to eq('Metric label not available')
      end
    end

    context 'with an empty test list' do
      it 'returns two empty hashes' do
        labels, lps = infra.get_tests_metrics(tests: [])
        expect(labels).to be_empty
        expect(lps).to be_empty
      end
    end

    it 'collects results for all test ids despite parallel execution' do
      labels, lps = infra.get_tests_metrics(tests: test_ids)
      expect(labels.keys).to match_array(test_ids)
      expect(lps.keys).to match_array(test_ids)
    end
  end

  describe '#fetch_metric_url (private)' do
    let(:metric_url) { 'https://example.org/metrics/some_metric' }
    let(:dcat_json) do
      JSON.dump([{ 'http://semanticscience.org/resource/SIO_000233' => [{ '@id' => metric_url }] }])
    end
    let(:fake_response) { instance_double(RestClient::Response, body: dcat_json) }

    before do
      allow(RestClient::Request).to receive(:execute).and_return(fake_response)
      allow(infra).to receive(:warn)
    end

    it 'extracts the metric URL from the SIO_000233 field in the DCAT JSON' do
      result = infra.send(:fetch_metric_url, 'test_a')
      expect(result).to eq(metric_url)
    end

    it 'calls the correct endpoint URL with JSON accept header' do
      infra.send(:fetch_metric_url, 'test_a')
      expect(RestClient::Request).to have_received(:execute).with(
        hash_including(
          method: :get,
          url: 'http://localhost:8282/tests/test_a',
          headers: { 'Accept' => 'application/json' }
        )
      )
    end
  end

  describe '#load_metric_graph (private)' do
    let(:metric_url) { 'https://example.org/metrics/some_metric' }
    let(:graph) { RDF::Graph.new }

    it 'loads the metric URL as Turtle' do
      allow(RDF::Graph).to receive(:load).and_return(graph)

      expect(infra.send(:load_metric_graph, metric_url)).to eq(graph)
      expect(RDF::Graph).to have_received(:load).with(metric_url, format: :turtle)
    end

    it 'returns an empty graph when loading fails' do
      allow(RDF::Graph).to receive(:load).and_raise(StandardError, 'unavailable metric')
      allow(infra).to receive(:warn)

      result = infra.send(:load_metric_graph, metric_url)

      expect(result).to be_a(RDF::Graph)
      expect(result).to be_empty
      expect(infra).to have_received(:warn).with(/DCAT Metric loading failed/)
    end
  end
end
