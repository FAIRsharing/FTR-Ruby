module FtrRuby
  ##
  # Represents the output/result of executing a FAIR test against a specific resource.
  #
  # This class generates a provenance-rich RDF graph describing a single test execution,
  # including the result score, log messages, summary, and optional guidance for improvement.
  #
  # The output follows the FAIR Test Registry (FTR) vocabulary and uses PROV for tracing
  # the execution activity and the tested entity.
  #
  # @example
  #   output = FtrRuby::Output.new(
  #     testedGUID: "https://doi.org/10.5281/zenodo.1234567",
  #     meta: test_meta_hash
  #   )
  #   output.score = "pass"
  #   output.comments << "Resource has a resolvable persistent identifier."
  #   jsonld = output.createEvaluationResponse
  #
  class Output
    include TripleEasy # get the :"triplify" function
    # triplify(s, p, o, repo, datatype: nil, context: nil, language: 'en')
    include RDF

    attr_accessor :score, :testedGUID, :testid, :uniqueid, :name, :description, :license, :dt, :metric, :softwareid,
                  :version, :summary, :completeness, :comments, :guidance, :creator, :protocol, :host, :basePath, :api

    OPUTPUT_VERSION = "1.1.1"

    ##
    # Creates a new test output instance.
    #
    # @param testedGUID [String] The identifier (usually URI) of the resource being tested
    # @param meta [Hash] Metadata about the test (same structure used by DCAT_Record)
    #
    def initialize(testedGUID:, meta:)
      @score = "indeterminate"
      @testedGUID = testedGUID
      @uniqueid = "urn:fairtestoutput:" + SecureRandom.uuid
      @name = meta[:testname]
      @description = meta[:description]
      @license = meta[:license] || "https://creativecommons.org/licenses/by/4.0/"
      @dt = Time.now.iso8601
      @metric = meta[:metric]
      @version = meta[:testversion]
      @summary = meta[:summary] || "Summary:"
      @completeness = "100"
      @comments = []
      @guidance = meta.fetch(:guidance, [])
      @creator = meta[:creator]
      @protocol   = meta[:protocol].to_s.split(%r{://}).first.to_s.strip.downcase
      @host       = meta[:host].to_s.sub(%r{\A[a-zA-Z][a-zA-Z0-9+\-.]*://}, "").split("/").first.to_s.strip
      @basePath   = meta[:basePath].to_s.sub(%r{\A[a-zA-Z][a-zA-Z0-9+\-.]*://[^/]*/}, "").gsub(%r{\A/+|/+\z}, "")
      testid      = meta[:testid].to_s.sub(%r{\A/+}, "")
      default_softwareid = "#{@protocol}://#{@host}/#{[@basePath, testid].reject(&:empty?).join("/")}"
      @softwareid = meta[:endpoint_url] || default_softwareid
      @api = meta[:endpoint_description] || "#{@softwareid}/api"
    end

    ##
    # Generates the full evaluation response as JSON-LD.
    #
    # Builds an RDF graph containing:
    # * A `ftr:TestExecutionActivity`
    # * A `ftr:TestResult` with score, summary, log, and guidance
    # * Links to the tested entity and the test software
    # * Provenance information
    #
    # @return [String] JSON-LD representation of the test result graph
    #
    def createEvaluationResponse
      g = RDF::Graph.new
      schema = RDF::Vocab::SCHEMA
      xsd = RDF::Vocab::XSD
      dct = RDF::Vocab::DC
      prov = RDF::Vocab::PROV
      dcat = RDF::Vocab::DCAT
      dqv = RDF::Vocabulary.new("https://www.w3.org/TR/vocab-dqv/")
      ftr = RDF::Vocabulary.new("https://w3id.org/ftr#")
      sio = RDF::Vocabulary.new("http://semanticscience.org/resource/")
      cwmo = RDF::Vocabulary.new("http://purl.org/cwmo/#")

      add_newline_to_comments

      if @summary =~ /^Summary$/
        @summary = "Summary of test results: #{comments[-1]}"
        @summary ||= "Summary of test results: #{comments[-2]}"
      end

      executionid = "urn:ostrails:testexecutionactivity:" + SecureRandom.uuid

      # tid = 'urn:ostrails:fairtestentity:' + SecureRandom.uuid
      # The entity is no longer an anonymous node, it is the GUID Of the tested input

      triplify(executionid, RDF.type, ftr.TestExecutionActivity, g)
      triplify(executionid, prov.wasAssociatedWith, softwareid, g)
      triplify(uniqueid, prov.wasGeneratedBy, executionid, g)

      triplify(uniqueid, RDF.type, ftr.TestResult, g)
      triplify(uniqueid, dct.identifier, uniqueid.to_s, g, datatype: xsd.string)
      triplify(uniqueid, dct.title, "#{name} OUTPUT", g)
      triplify(uniqueid, dct.description, "OUTPUT OF #{description}", g)
      triplify(uniqueid, dct.license, license, g)
      triplify(uniqueid, prov.value, @score, g)
      triplify(uniqueid, ftr.summary, summary, g)
      triplify(uniqueid, RDF::Vocab::PROV.generatedAtTime, dt, g)
      triplify(uniqueid, ftr.log, comments.join, g)
      triplify(uniqueid, ftr.completion, completeness, g)

      triplify(uniqueid, ftr.outputFromTest, softwareid, g)
      triplify(softwareid, RDF.type, ftr.Test, g)
      triplify(softwareid, RDF.type, schema.SoftwareApplication, g)
      triplify(softwareid, RDF.type, dcat.DataService, g)
      triplify(softwareid, dct.identifier, softwareid.to_s, g, datatype: xsd.string)
      triplify(softwareid, dct.title, "#{name}", g)
      triplify(softwareid, dct.description, description, g)
      triplify(softwareid, dcat.endpointDescription, api, g) # returns yaml
      triplify(softwareid, dcat.endpointURL, softwareid, g) # POST to execute
      triplify(softwareid, "http://www.w3.org/ns/dcat#version", "#{version} OutputVersion:#{OPUTPUT_VERSION}", g) # dcat namespace in library has no version - dcat 2 not 3
      triplify(softwareid, dct.license, "https://github.com/wilkinsonlab/FAIR-Core-Tests/blob/main/LICENSE", g)
      triplify(softwareid, sio["SIO_000233"], metric, g) # implementation of

      # deprecated after release 1.0
      # triplify(uniqueid, prov.wasDerivedFrom, tid, g)
      # triplify(executionid, prov.used, tid, g)
      # triplify(tid, RDF.type, prov.Entity, g)
      # triplify(tid, schema.identifier, testedGUID, g, xsd.string)
      # triplify(tid, schema.url, testedGUID, g) if testedGUID =~ %r{^https?://}
      testedguidnode = "urn:ostrails:testedidentifiernode:" + SecureRandom.uuid

      begin
        triplify(uniqueid, ftr.assessmentTarget, testedguidnode, g)
        triplify(executionid, prov.used, testedguidnode, g)
        triplify(testedguidnode, RDF.type, prov.Entity, g)
        triplify(testedguidnode, dct.identifier, testedGUID, g, datatype: xsd.string)
      rescue StandardError
        triplify(uniqueid, ftr.assessmentTarget, "not a URI", g)
        triplify(executionid, prov.used, "not a URI", g)
        @score = "fail"
      end

      unless @score == "pass"
        guidance.each do |advice, label|
          adviceid = "urn:ostrails:testexecutionactivity:advice:" + SecureRandom.uuid
          triplify(uniqueid, ftr.suggestion, adviceid, g)
          triplify(adviceid, RDF.type, ftr.GuidanceContext, g)
          triplify(adviceid, RDFS.label, label, g)
          triplify(adviceid, dct.description, label, g)
          triplify(adviceid, sio["SIO_000339"], RDF::URI.new(advice), g)
        end
      end

      #      g.dump(:jsonld)
      w = RDF::Writer.for(:jsonld)
      w.dump(g, nil, prefixes: {
               xsd: RDF::Vocab::XSD,
               prov: RDF::Vocab::PROV,
               dct: RDF::Vocab::DC,
               dcat: RDF::Vocab::DCAT,
               ftr: ftr,
               sio: sio,
               schema: schema
             })
    end

    class << self
      attr_reader :comments
    end

    def self.clear_comments
      @comments = []
    end

    def add_newline_to_comments
      cleancomments = []
      @comments.each do |c|
        c += "\n" unless c =~ /\n$/
        cleancomments << c
      end
      @comments = cleancomments
    end
  end
end
