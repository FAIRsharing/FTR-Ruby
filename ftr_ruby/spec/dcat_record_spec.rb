# frozen_string_literal: true

require_relative "./spec_helper"

RSpec.describe FtrRuby::DCAT_Record do
  let(:minimal_meta) do
    {
      testid: "ftr-test-001",
      testname: "Test Persistent Identifier",
      description: "Checks if the resource has a persistent identifier.",
      creator: "https://orcid.org/0000-0002-1825-0097",
      metric: "https://w3id.org/ftr/metric/F1-01M",
      protocol: "https",
      host: "tests.ostrails.eu",
      basePath: "api"
    }
  end

  subject(:record) { described_class.new(meta: minimal_meta) }

  describe "#initialize" do
    it "sets required attributes" do
      expect(record.testid).to eq("ftr-test-001")
      expect(record.testname).to eq("Test Persistent Identifier")
      expect(record.description).to eq("Checks if the resource has a persistent identifier.")
    end

    it "builds correct URLs" do
      expect(record.identifier).to start_with("https://tests.ostrails.eu/api/")
      expect(record.end_url).to include("/assess/test/")
      expect(record.end_desc).to end_with("/api")
    end

    it "applies sensible defaults" do
      expect(record.dctype).to eq("http://edamontology.org/operation_2428")
      expect(record.supportedby).to include("https://tools.ostrails.eu/champion")
      expect(record.isapplicablefor).to include("https://schema.org/Dataset")
    end

    context "when required metadata is missing" do
      let(:minimal_meta) { super().merge(creator: nil) }

      it "warns that the record is invalid" do
        expect { described_class.new(meta: minimal_meta) }.to output(/this record is invalid/).to_stderr
      end
    end
  end

  describe "#get_dcat" do
    let(:graph) { record.get_dcat }
    let(:me) { RDF::URI(record.identifier) }

    it "returns an RDF::Graph" do
      expect(graph).to be_a(RDF::Graph)
    end

    it "contains the test as dcat:DataService and ftr:Test" do
      expect(graph).to have_statement(RDF::Statement.new(me, RDF.type, RDF::Vocab::DCAT.DataService))
      expect(graph).to have_statement(RDF::Statement.new(me, RDF.type, RDF::Vocabulary.new("https://w3id.org/ftr#").Test))
    end

    it "includes basic metadata" do
      expect(graph).to have_statement(RDF::Statement.new(me, RDF::Vocab::DC.title, RDF::Literal(record.testname, language: :en)))
      expect(graph).to have_statement(RDF::Statement.new(me, RDF::Vocab::DC.description, RDF::Literal(record.description, language: :en)))
    end

    it "includes the metric relationship" do
      sio = RDF::Vocabulary.new("http://semanticscience.org/resource/")

      expect(graph).to have_statement(RDF::Statement.new(me, sio["SIO_000233"], RDF::URI(minimal_meta[:metric])))
    end

    context "with keyword and theme metadata" do
      let(:minimal_meta) do
        super().merge(
          keywords: ["FAIR", "persistent identifier"],
          themes: ["https://example.org/theme/identifiers"]
        )
      end

      it "adds each keyword as a DCAT keyword" do
        expect(graph).to have_statement(RDF::Statement.new(me, RDF::Vocab::DCAT.keyword, RDF::Literal("FAIR", language: :en)))
        expect(graph).to have_statement(
          RDF::Statement.new(me, RDF::Vocab::DCAT.keyword, RDF::Literal("persistent identifier", language: :en))
        )
      end

      it "adds each theme as a DCAT theme" do
        expect(graph).to have_statement(
          RDF::Statement.new(me, RDF::Vocab::DCAT.theme, RDF::URI("https://example.org/theme/identifiers"))
        )
      end
    end

    context "with contact individuals" do
      let(:minimal_meta) do
        super().merge(
          individuals: [
            { "name" => "Alice Example", "email" => "alice@example.org" },
            { "name" => "Bob Example" }
          ]
        )
      end

      it "adds individual contact point details" do
        vcard = RDF::Vocabulary.new("http://www.w3.org/2006/vcard/ns#")
        contact_points = graph.query([me, RDF::Vocab::DCAT.contactPoint, nil]).map(&:object)
        alice = contact_points.find do |contact_point|
          graph.has_statement?(RDF::Statement.new(contact_point, vcard.fn, RDF::Literal("Alice Example", language: :en)))
        end

        expect(contact_points.size).to eq(2)
        expect(graph).to have_statement(RDF::Statement.new(alice, RDF.type, vcard.Individual))
        expect(graph).to have_statement(RDF::Statement.new(alice, vcard.hasEmail, RDF::URI("mailto:alice@example.org")))
      end
    end

    context "with contact organizations" do
      let(:minimal_meta) do
        super().merge(
          organizations: [
            { "name" => "Example Organization", "url" => "https://example.org" }
          ]
        )
      end

      it "adds organization contact point details" do
        vcard = RDF::Vocabulary.new("http://www.w3.org/2006/vcard/ns#")
        contact_point = graph.query([me, RDF::Vocab::DCAT.contactPoint, nil]).map(&:object).first

        expect(graph).to have_statement(RDF::Statement.new(contact_point, RDF.type, vcard.Organization))
        expect(graph).to have_statement(
          RDF::Statement.new(contact_point, vcard["organization-name"], RDF::Literal("Example Organization", language: :en))
        )
        expect(graph).to have_statement(RDF::Statement.new(contact_point, vcard.url, RDF::URI("https://example.org")))
      end
    end
  end
end
