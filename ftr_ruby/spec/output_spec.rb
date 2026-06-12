# frozen_string_literal: true

require "spec_helper"

RSpec.describe FtrRuby::Output do
  let(:meta) do
    {
      testname: "Test Persistent Identifier",
      description: "Checks persistent identifier presence.",
      testversion: "1.0.0",
      metric: "https://w3id.org/ftr/metric/F1-01M",
      protocol: "https",
      host: "tests.ostrails.eu",
      basePath: "api",
      testid: "ftr-test-001"
    }
  end

  let(:tested_guid) { "https://doi.org/10.5281/zenodo.12345678" }

  subject(:output) { described_class.new(testedGUID: tested_guid, meta: meta) }

  describe "#initialize" do
    it "sets uniqueid as a URN" do
      expect(output.uniqueid).to start_with("urn:fairtestoutput:")
    end

    it "sets softwareid correctly" do
      expect(output.softwareid).to include("https://tests.ostrails.eu/api/ftr-test-001")
    end

    context "when endpoint metadata is provided" do
      let(:meta) do
        super().merge(
          endpoint_url: "https://fair-tests.fairsharing.org/test/ft_f1_m_metadata_id_unique",
          endpoint_description: "https://fair-tests.fairsharing.org/test_descriptions/ft_f1_m_metadata_id_unique/api"
        )
      end

      it "keeps the computed test software id" do
        expect(output.softwareid).to eq("https://tests.ostrails.eu/api/ftr-test-001")
      end

      it "uses endpoint_url as the DCAT endpoint URL" do
        expect(output.endpoint_url).to eq("https://fair-tests.fairsharing.org/test/ft_f1_m_metadata_id_unique")
      end

      it "uses endpoint_description as the API description" do
        expect(output.api).to eq("https://fair-tests.fairsharing.org/test_descriptions/ft_f1_m_metadata_id_unique/api")
      end
    end

    it "defaults score to indeterminate" do
      expect(output.score).to eq("indeterminate")
    end

    describe "URL component normalization" do
      context "when protocol includes the scheme suffix (e.g. 'https://')" do
        let(:meta) { super().merge(protocol: "https://") }
        it { expect(output.protocol).to eq("https") }
      end

      context "when protocol is uppercased (e.g. 'HTTPS')" do
        let(:meta) { super().merge(protocol: "HTTPS") }
        it { expect(output.protocol).to eq("https") }
      end

      context "when host includes a scheme prefix (e.g. 'https://tests.ostrails.eu')" do
        let(:meta) { super().merge(host: "https://tests.ostrails.eu") }
        it { expect(output.host).to eq("tests.ostrails.eu") }
      end

      context "when host includes a port number (e.g. 'tests.ostrails.eu:8080')" do
        let(:meta) { super().merge(host: "tests.ostrails.eu:8080") }
        it "preserves the port in host" do
          expect(output.host).to eq("tests.ostrails.eu:8080")
        end
      end

      context "when basePath has leading and trailing slashes (e.g. '/api/')" do
        let(:meta) { super().merge(basePath: "/api/") }
        it { expect(output.basePath).to eq("api") }
      end

      context "when basePath has internal slashes (e.g. '/path/to/test')" do
        let(:meta) { super().merge(basePath: "/path/to/test") }

        it "strips only the leading slash, preserving internal separators" do
          expect(output.basePath).to eq("path/to/test")
        end

        it "assembles softwareid without corrupting the path" do
          expect(output.softwareid).to eq("https://tests.ostrails.eu/path/to/test/ftr-test-001")
        end
      end

      context "when testid has a leading slash (e.g. '/ftr-test-001')" do
        let(:meta) { super().merge(testid: "/ftr-test-001") }
        it "strips the leading slash in softwareid" do
          expect(output.softwareid).to eq("https://tests.ostrails.eu/api/ftr-test-001")
        end
      end

      context "when basePath is empty" do
        let(:meta) { super().merge(basePath: "") }
        it "builds softwareid without a double slash" do
          expect(output.softwareid).to eq("https://tests.ostrails.eu/ftr-test-001")
        end
      end

      context "when all inputs are messy (mixed case, extra slashes, scheme prefixes)" do
        let(:meta) do
          super().merge(
            protocol: "HTTPS://",
            host: "https://tests.ostrails.eu/",
            basePath: "/path/to/test/",
            testid: "/ftr-test-001"
          )
        end
        it "assembles a clean softwareid" do
          expect(output.softwareid).to eq("https://tests.ostrails.eu/path/to/test/ftr-test-001")
        end
      end
    end
  end

  describe "#createEvaluationResponse" do
    let(:jsonld) { output.createEvaluationResponse }

    it "returns a JSON-LD string" do
      expect(jsonld).to be_a(String)
      expect(jsonld).to include("@context")
      expect(jsonld).to include("TestResult")
    end

    it "includes the tested GUID" do
      expect(jsonld).to include(tested_guid)
    end

    it "includes the test name in the output" do
      expect(jsonld).to include(meta[:testname])
    end

    context "when summary is the placeholder value" do
      before do
        output.summary = "Summary"
        output.comments << "Final assessment comment"
      end

      it "builds the summary from the latest comment" do
        expect(jsonld).to include("Summary of test results: Final assessment comment")
      end
    end

    context "when serializing the tested GUID fails" do
      before do
        allow(output).to receive(:triplify).and_wrap_original do |method, *args, **kwargs|
          raise StandardError, "bad tested GUID" if args[1] == RDF::Vocab::DC.identifier && args[2] == tested_guid

          method.call(*args, **kwargs)
        end
      end

      it "records a fallback assessment target and marks the output as failed" do
        expect(jsonld).to include("not a URI")
        expect(output.score).to eq("fail")
      end
    end

    context "when endpoint metadata is provided" do
      let(:meta) do
        super().merge(
          endpoint_url: "https://fair-tests.fairsharing.org/test/ft_f1_m_metadata_id_unique",
          endpoint_description: "https://fair-tests.fairsharing.org/test_descriptions/ft_f1_m_metadata_id_unique/api"
        )
      end

      it "includes the provided endpoint URL and endpoint description" do
        expect(jsonld).to include(meta[:endpoint_url])
        expect(jsonld).to include(meta[:endpoint_description])
      end

      it "keeps the computed identifier value" do
        expect(jsonld).to include("https://tests.ostrails.eu/api/ftr-test-001")
      end
    end

    context "when score is pass" do
      before { output.score = "pass" }

      it "does not add guidance suggestions" do
        json = JSON.parse(jsonld)
        # This is a rough check — adjust based on your exact JSON-LD structure
        expect(json.to_s).not_to include("suggestion")
      end
    end

    context "when score is not pass" do
      before do
        output.score = "fail"
        output.guidance = [["https://fix.example.org", "Add a PID"]]
      end

      it "includes guidance suggestions" do
        expect(output.createEvaluationResponse).to include("GuidanceContext")
      end
    end
  end

  describe ".clear_comments" do
    it "clears the comments class variable" do
      FtrRuby::Output.clear_comments
      expect(FtrRuby::Output.comments).to eq([])
    end
  end

  describe "#add_newline_to_comments" do
    it "adds a trailing newline to comments that do not already have one" do
      output.comments << "first comment"
      output.comments << "second comment\n"

      output.add_newline_to_comments

      expect(output.comments).to eq(["first comment\n", "second comment\n"])
    end
  end
end
