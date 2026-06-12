# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe FtrRuby::OpenAPI do
  let(:meta) do
    {
      testid: "ftr-test-001",
      testname: "Test Persistent Identifier",
      testversion: "1.2.3",
      metric: "https://w3id.org/ftr/metric/F1-01M",
      description: "Checks persistent identifier presence.",
      indicators: "https://w3id.org/ftr/indicator/F1-01M",
      organization: "FAIR Test Registry",
      org_url: "https://fairsharing.org",
      responsible_developer: "Test Developer",
      email: "developer@example.org",
      creator: "https://orcid.org/0000-0002-1825-0097",
      protocol: "https://",
      host: "tests.ostrails.eu/",
      basePath: "/api/",
      response_description: "The result of evaluating the supplied GUID.",
      schemas: {}
    }
  end

  subject(:openapi) { described_class.new(meta: meta) }

  describe "#initialize" do
    it "copies metadata fields" do
      expect(openapi.testid).to eq("ftr-test-001")
      expect(openapi.title).to eq("Test Persistent Identifier")
      expect(openapi.version).to eq("1.2.3")
      expect(openapi.metric).to eq("https://w3id.org/ftr/metric/F1-01M")
      expect(openapi.indicator).to eq("https://w3id.org/ftr/indicator/F1-01M")
      expect(openapi.organization).to eq("FAIR Test Registry")
      expect(openapi.org_url).to eq("https://fairsharing.org")
      expect(openapi.responsible_developer).to eq("Test Developer")
      expect(openapi.email).to eq("developer@example.org")
      expect(openapi.creator).to eq("https://orcid.org/0000-0002-1825-0097")
      expect(openapi.response_description).to eq("The result of evaluating the supplied GUID.")
      expect(openapi.schemas).to eq({})
      expect(openapi.endpointpath).to eq("assess/test")
    end

    it "normalizes URL components for the server URL" do
      expect(openapi.protocol).to eq("https")
      expect(openapi.host).to eq("tests.ostrails.eu")
      expect(openapi.basePath).to eq("/api")
    end

    context "when basePath does not start with a slash" do
      let(:meta) { super().merge(basePath: "api") }

      it "adds the leading slash" do
        expect(openapi.basePath).to eq("/api")
      end
    end
  end

  describe "#get_api" do
    let(:document) { openapi.get_api }
    let(:parsed) { YAML.safe_load(document) }

    it "returns an OpenAPI 3 document" do
      expect(parsed.fetch("openapi")).to eq("3.0.0")
      expect(parsed.dig("info", "version")).to eq("1.2.3")
      expect(parsed.dig("info", "title")).to eq("Test Persistent Identifier")
      expect(parsed.dig("info", "x-tests_metric")).to eq("https://w3id.org/ftr/metric/F1-01M")
      expect(parsed.dig("info", "x-applies_to_principle")).to eq("https://w3id.org/ftr/indicator/F1-01M")
    end

    it "includes contact metadata" do
      contact = parsed.dig("info", "contact")

      expect(contact.fetch("x-organization")).to eq("FAIR Test Registry")
      expect(contact.fetch("url")).to eq("https://fairsharing.org")
      expect(contact.fetch("name")).to eq("Test Developer")
      expect(contact.fetch("x-role")).to eq("responsible developer")
      expect(contact.fetch("email")).to eq("developer@example.org")
      expect(contact.fetch("x-id")).to eq("https://orcid.org/0000-0002-1825-0097")
    end

    it "describes the test endpoint and request schema" do
      path = parsed.dig("paths", "/ftr-test-001", "post")

      expect(path.dig("requestBody", "required")).to be(true)
      expect(path.dig("requestBody", "content", "application/json", "schema", "$ref")).to eq("#/components/schemas/schemas")
      expect(path.dig("responses", "200", "description")).to eq("The result of evaluating the supplied GUID.")
      expect(parsed.dig("components", "schemas", "schemas", "required")).to eq(["resource_identifier"])
      expect(parsed.dig("components", "schemas", "schemas", "properties", "resource_identifier", "type")).to eq("string")
    end

    it "builds the server URL from normalized components" do
      expect(parsed.fetch("servers")).to eq([{ "url" => "https://tests.ostrails.eu/api/assess/test" }])
    end

    context "with multiline markdown descriptions" do
      let(:meta) do
        super().merge(
          description: "First paragraph.\n\n## Heading\nSecond paragraph.",
          response_description: "Line one.\n\n## Response heading\nLine two."
        )
      end

      it "keeps markdown lines inside YAML block scalars" do
        expect { YAML.safe_load(document) }.not_to raise_error
        expect(parsed.dig("info", "description")).to include("## Heading")
        expect(parsed.dig("info", "description")).to include("Second paragraph.")
        expect(parsed.dig("paths", "/ftr-test-001", "post", "responses", "200", "description")).to include("## Response heading")
        expect(parsed.dig("paths", "/ftr-test-001", "post", "responses", "200", "description")).to include("Line two.")
      end
    end
  end
end
