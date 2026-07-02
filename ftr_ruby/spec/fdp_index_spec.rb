# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe FtrRuby::FDPIndex do
  describe ".retrieve_tests_from_index" do
    let(:endpoint) { "https://example.org/repositories/fdp-index" }
    let(:client) { instance_double(SPARQL::Client) }
    let(:solution) do
      {
        sub: RDF::URI("https://example.org/test"),
        identifier: RDF::Literal("test-id"),
        title: RDF::Literal("Test title"),
        description: RDF::Literal("Test description"),
        endpoint: RDF::URI("https://example.org/test/endpoint"),
        openapi: RDF::URI("https://example.org/test/api"),
        dimension: RDF::URI("https://example.org/dimension"),
        objects: RDF::URI("https://schema.org/Dataset"),
        domain: RDF::URI("https://example.org/domain"),
        benchmark_or_metric: RDF::URI("https://example.org/metric")
      }
    end
    let(:results) { double("SPARQL results") }

    before do
      allow(SPARQL::Client).to receive(:new).with(endpoint).and_return(client)
      allow(results).to receive(:each_solution).and_yield(solution)
      allow(client).to receive(:query).and_return(results)
    end

    it "queries the index endpoint and returns test metadata hashes" do
      tests = described_class.retrieve_tests_from_index(indexendpoint: endpoint)

      expect(client).to have_received(:query).with(include("SELECT distinct ?sub ?identifier ?title ?description"))
      expect(tests).to eq([
                            {
                              subj: "https://example.org/test",
                              identifier: "test-id",
                              title: "Test title",
                              description: "Test description",
                              endpoint: "https://example.org/test/endpoint",
                              openapi: "https://example.org/test/api",
                              dimension: "https://example.org/dimension",
                              objects: "https://schema.org/Dataset",
                              domain: "https://example.org/domain",
                              benchmark_or_metric: "https://example.org/metric"
                            }
                          ])
    end

    it "prints an error and returns an empty list when the SPARQL query fails" do
      allow(client).to receive(:query).and_raise(StandardError, "index unavailable")

      expect do
        expect(described_class.retrieve_tests_from_index(indexendpoint: endpoint)).to eq([])
      end.to output(/Error executing SPARQL query: index unavailable/).to_stdout
    end
  end

  describe ".get_metrics_labels_for_tests" do
    let(:metric) { "https://example.org/metric" }
    let(:tests) { [{ benchmark_or_metric: metric }] }
    let(:cache_dir) { Dir.mktmpdir }
    let(:repository) { RDF::Repository.new }
    let(:query) { double("SPARQL metric label query") }

    before do
      stub_const("#{described_class}::CACHE_DIR", cache_dir)
      allow(described_class).to receive(:load_from_cache).and_return(repository)
      allow(described_class).to receive(:warn)
      allow(SPARQL).to receive(:parse).and_return(query)
    end

    after do
      FileUtils.remove_entry(cache_dir) if File.exist?(cache_dir)
    end

    it "uses a cached repository to resolve metric labels" do
      allow(query).to receive(:execute).with(repository).and_return([{ label: RDF::Literal("Cached Metric") }])

      labels = described_class.get_metrics_labels_for_tests(tests: tests)

      expect(described_class).to have_received(:load_from_cache)
      expect(labels).to eq(metric => "Cached Metric")
    end

    it "uses the in-memory cache when the same metric appears more than once" do
      allow(query).to receive(:execute).with(repository).and_return([{ label: RDF::Literal("Cached Metric") }])

      labels = described_class.get_metrics_labels_for_tests(tests: [tests.first, tests.first])

      expect(described_class).to have_received(:load_from_cache).once
      expect(labels).to eq(metric => "Cached Metric")
    end

    it "falls back to Unnamed Metric when no label is found" do
      allow(query).to receive(:execute).with(repository).and_return([])

      labels = described_class.get_metrics_labels_for_tests(tests: tests)

      expect(labels).to eq(metric => "Unnamed Metric")
    end

    context "when the metric is not cached" do
      let(:reader) { double("RDF reader") }
      let(:fetched_repository) { instance_double(RDF::Repository) }

      before do
        allow(described_class).to receive(:load_from_cache).and_return(nil)
        allow(RDF::Repository).to receive(:new).and_return(fetched_repository)
        allow(fetched_repository).to receive(:<<)
        allow(RDF::Reader).to receive(:open).and_yield(reader)
        allow(described_class).to receive(:save_to_cache)
      end

      it "fetches RDF, saves it to disk cache, and resolves the label" do
        allow(query).to receive(:execute).with(fetched_repository).and_return([{ label: RDF::Literal("Fetched Metric") }])

        labels = described_class.get_metrics_labels_for_tests(tests: tests)

        expect(RDF::Reader).to have_received(:open).with(metric, headers: { "Accept" => "application/ld+json" })
        expect(fetched_repository).to have_received(:<<).with(reader)
        expect(described_class).to have_received(:save_to_cache)
        expect(labels).to eq(metric => "Fetched Metric")
      end

      it "returns an error label when fetching RDF fails" do
        allow(RDF::Reader).to receive(:open).and_raise(StandardError, "not found")

        labels = described_class.get_metrics_labels_for_tests(tests: tests)

        expect(labels).to eq(metric => "Unable to resolve #{metric} to RDF metadata")
      end
    end
  end

  describe ".load_from_cache" do
    let(:cache_file) { File.join(Dir.mktmpdir, "repository.bin") }
    let(:repository) { RDF::Repository.new }

    after do
      dir = File.dirname(cache_file)
      FileUtils.remove_entry(dir) if File.exist?(dir)
    end

    it "returns nil when the cache file does not exist" do
      expect(described_class.load_from_cache(cache_file)).to be_nil
    end

    it "returns a repository from a fresh cache file" do
      File.open(cache_file, "wb") do |file|
        Marshal.dump(Time.now, file)
        Marshal.dump(repository, file)
      end

      expect(described_class.load_from_cache(cache_file)).to be_a(RDF::Repository)
    end

    it "returns nil when the cache file has expired" do
      File.open(cache_file, "wb") do |file|
        Marshal.dump(Time.now - described_class::CACHE_EXPIRY - 1, file)
        Marshal.dump(repository, file)
      end

      expect(described_class.load_from_cache(cache_file)).to be_nil
    end

    it "warns and returns nil when the cache cannot be loaded" do
      File.write(cache_file, "not marshal data")

      expect do
        expect(described_class.load_from_cache(cache_file)).to be_nil
      end.to output(/Error loading cache from/).to_stderr
    end
  end

  describe ".save_to_cache" do
    let(:cache_file) { File.join(Dir.mktmpdir, "repository.bin") }
    let(:repository) { RDF::Repository.new }

    after do
      dir = File.dirname(cache_file)
      FileUtils.remove_entry(dir) if File.exist?(dir)
    end

    it "writes a timestamp and repository to the cache file" do
      described_class.save_to_cache(cache_file, repository)

      File.open(cache_file, "rb") do |file|
        expect(Marshal.load(file)).to be_a(Time)
        expect(Marshal.load(file)).to be_a(RDF::Repository)
      end
    end

    it "warns when the cache cannot be written" do
      allow(File).to receive(:open).and_raise(StandardError, "read-only")

      expect do
        described_class.save_to_cache(cache_file, repository)
      end.to output(/Error saving cache to .*read-only/).to_stderr
    end
  end
end
