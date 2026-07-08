##
# Module containing FAIR Test Registry (FTR) related classes.
module FtrRuby
  ##
  # Represents a single FAIR Test as a DCAT-compliant DataService with additional
  # FAIR-specific metadata.
  #
  # This class generates RDF metadata (in a DCAT + DQV + FTR vocabulary profile)
  # describing a test that can be used to assess FAIR compliance of digital objects
  # (typically datasets). The resulting graph follows the DCAT-AP style for Data Services,
  # extended with FAIR Test Registry (FTR) semantics.
  #
  # == Usage
  #
  #   meta = {
  #     testid:        "ftr-rda-f1-01m",
  #     testname:      "FAIR Test F1-01M: Persistent Identifier",
  #     description:   "Checks whether the digital object has a globally unique persistent identifier...",
  #     keywords:      ["FAIR", "persistent identifier", "F1"],
  #     creator:       "https://orcid.org/0000-0001-2345-6789",
  #     indicators:    ["https://w3id.org/ftr/indicator/F1-01M"],
  #     metric:        "https://w3id.org/ftr/metric/F1-01M",
  #     license:       "https://creativecommons.org/licenses/by/4.0/",
  #     testversion:   "1.0",
  #     # ... other fields
  #   }
  #
  #   record = FtrRuby::DCAT_Record.new(meta: meta)
  #   graph  = record.get_dcat
  #
  class DCAT_Record
    attr_accessor :identifier, :testname, :description, :keywords, :creator,
                  :indicators, :end_desc, :end_url, :dctype, :testid, :supportedby,
                  :license, :themes, :testversion, :implementations, :isapplicablefor, :applicationarea,
                  :organizations, :individuals, :protocol, :host, :basePath, :metric, :landingpage, :definedby

    require_relative "./output"
    include TripleEasy # get the :"triplify" function
    # triplify(s, p, o, repo, datatype: nil, context: nil, language: 'en')

    ##
    # Creates a new DCAT_Record from metadata hash.
    #
    # @param meta [Hash] Metadata describing the FAIR test.
    # @option meta [String] :testid           Unique identifier for the test (used in URLs)
    # @option meta [String] :testname         Human-readable name/title of the test
    # @option meta [String] :description      Detailed description of what the test does
    # @option meta [String, Array<String>] :keywords   Keywords describing the test
    # @option meta [String] :creator          URI or literal identifying the creator
    # @option meta [String, Array<String>] :indicators  URIs of the FAIR indicators this test addresses
    # @option meta [String] :metric           URI of the metric this test implements
    # @option meta [String] :license          License URI for the test
    # @option meta [String, Array<String>] :themes     Thematic categories (DCAT themes)
    # @option meta [String] :testversion      Version of the test
    # @option meta [Array<Hash>] :individuals List of contact individuals (name, email)
    # @option meta [Array<Hash>] :organizations List of responsible organizations (name, url)
    # @option meta [String] :protocol         Protocol (http/https)
    # @option meta [String] :host             Hostname of the test service
    # @option meta [String] :basePath         Base path of the test service
    # @option meta [String] :endpoint_url     URL of the test service (will be auto-generated if not supplied).  Note that endpoint path is defined by the FTR spec to be assess/test, but this is not enforced
    # @option meta [String] :endpoint_desc    URL to the OpenAPI docs (will be auto-generated if not supplied)
    # @option meta [String] :identifier       Identifier of test (will be auto-generated from host, protocol, basepath, testid if not supplied)
    #
    # @note Several fields have sensible defaults (e.g. +dctype+, +supportedby+, +applicationarea+).
    #       The +end_url+ and +identifier+ are automatically constructed from +protocol+, +host+,
    #       +basePath+, and +testid+.
    #
    def initialize(meta:)
      indics = [meta[:indicators]] unless meta[:indicators].is_a? Array
      @indicators = indics
      @testid = meta[:testid]
      @testname = meta[:testname]
      @metric = meta[:metric]
      @description = meta[:description] || "No description provided"
      @keywords = meta[:keywords] || []
      @keywords = [@keywords] unless @keywords.is_a? Array
      @creator = meta[:creator]
      @dctype = meta[:dctype] || "http://edamontology.org/operation_2428"
      @supportedby = meta[:supportedby] || ["https://tools.ostrails.eu/champion"]
      @applicationarea = meta[:applicationarea] || ["http://www.fairsharing.org/ontology/subject/SRAO_0000401"]
      @isapplicablefor = meta[:isapplicablefor] || ["https://schema.org/Dataset"]
      @license = meta[:license] || "No License"
      @themes = meta[:themes] || []
      @themes = [@themes] unless @themes.is_a? Array
      @testversion = meta[:testversion] || "unversioned"
      @organizations = meta[:organizations] || []
      @individuals = meta[:individuals] || []
      @protocol = meta[:protocol]
      @host = meta[:host]
      @basePath = meta[:basePath]
      @definedby =  meta[:definedby] || @identifier
      @landingpage = meta[:landingPage] || @identifier

      cleanhost = @host.gsub(%r{/$}, "")
      cleanpath = @basePath.gsub(%r{/$}, "")
      endpointpath = "assess/test"

      # The two overrides below are needed for FAIRsharing tests to ensure that the proper endpoint is shown in
      # test output. Without this, endpoint URLs and descriptions pointing to non-existent URLs are generated.
      @end_desc = meta[:end_desc]
      @end_url = meta[:end_url]

      # Override the endpoint URL if provided in the meta data.
      @end_url = meta[:endpoint_url] || "#{protocol}://#{cleanhost}/#{cleanpath}/#{endpointpath}/#{testid}"

      # Override the endpoint description if provided in the meta data.
      @end_desc = meta[:endpoint_description] || "#{protocol}://#{cleanhost}/#{cleanpath}/#{testid}/api"

      # Override the endpoint description if provided in the meta data.
      @identifier =  meta[:identifier] || "#{protocol}://#{cleanhost}/#{cleanpath}/#{testid}"

      unless @testid && @testname && @description && @creator && @end_desc && @end_url && @protocol && @host && @basePath
        warn "this record is invalid - it is missing one of  testid testname description creator  end_desc end_url protocol  host  basePath"
      end
    end

    ##
    # Returns an RDF::Graph containing the DCAT metadata for this test.
    #
    # The graph describes the test as both a +dcat:DataService+ and an +ftr:Test+.
    # It includes:
    #
    # * Core DCAT properties (identifier, title, description, keywords, landing page, etc.)
    # * FAIR-specific extensions via the FTR vocabulary
    # * Contact points (individuals and organizations) using vCard
    # * Link to the metric it implements (SIO)
    # * Supported-by relationships, application areas, and applicability statements
    #
    # @return [RDF::Graph] RDF graph with the complete DCAT record
    #
    def get_dcat
      schema = RDF::Vocab::SCHEMA
      dcterms = RDF::Vocab::DC
      xsd = RDF::Vocab::XSD
      dcat = RDF::Vocab::DCAT
      sio = RDF::Vocabulary.new("http://semanticscience.org/resource/")
      ftr = RDF::Vocabulary.new("https://w3id.org/ftr#")
      dqv = RDF::Vocabulary.new("http://www.w3.org/ns/dqv#")
      vcard = RDF::Vocabulary.new("http://www.w3.org/2006/vcard/ns#")
      dpv = RDF::Vocabulary.new("https://w3id.org/dpv#")

      g = RDF::Graph.new
      #      me = "#{identifier}/about"   # at the hackathon we decided that the test id would return the metadata
      # so now there is no need for /about
      me = "#{identifier}"

      triplify(me, RDF.type, dcat.DataService, g)
      triplify(me, RDF.type, ftr.Test, g)

      # triplify tests and rejects anything that is empty or nil  --> SAFE
      # Test Unique Identifier	dcterms:identifier	Literal
      triplify(me, dcterms.identifier, identifier.to_s, g, datatype: xsd.string)

      # Title/Name of the test	dcterms:title	Literal
      triplify(me, dcterms.title, testname, g)

      # Description	dcterms:description	Literal
      # descriptions.each do |d|
      #   triplify(me, dcterms.description, d, g)
      # end
      triplify(me, dcterms.description, description, g)

      # Keywords	dcat:keyword	Literal
      keywords.each do |kw|
        triplify(me, dcat.keyword, kw, g)
      end

      # Test creator	dcterms:creator	dcat:Agent (URI)
      triplify(me, dcterms.creator, creator, g)

      # Dimension	ftr:indicator
      indicators.each do |ind|
        triplify(me, dqv.inDimension, ind, g)
      end

      # API description	dcat:endpointDescription	rdfs:Resource
      triplify(me, dcat.endpointDescription, end_desc, g)

      # API URL	dcat:endpointURL	rdfs:Resource
      triplify(me, dcat.endpointURL, end_url, g)

      # API URL	dcat:landingPage	rdfs:Resource
      triplify(me, dcat.landingPage, landingpage, g)

      # pointer to this turtle file
      triplify(me, RDF::Vocab::RDFS.isDefinedBy, definedby, g)

      # Functional Descriptor/Operation	dcterms:type	xsd:anyURI
      triplify(me, dcterms.type, dctype, g)

      # License	dcterms:license	xsd:anyURI
      triplify(me, dcterms.license, license, g)

      # Semantic Annotation	dcat:theme	xsd:anyURI
      themes.each do |theme|
        triplify(me, dcat.theme, theme, g)
      end

      # Version	dcat:version	rdfs:Literal
      triplify(me, RDF::Vocab::DCAT.to_s + "version", testversion, g)

      triplify(me, sio["SIO_000233"], metric, g) # is implementation of
      triplify(metric, RDF.type, dqv.Metric, g) # is implementation of

      # Responsible	dcat:contactPoint	dcat:Kind (includes Individual/Organization)
      individuals.each do |i|
        # i = {name: "Mark WAilkkinson", "email": "asmlkfj;askjf@a;lksdjfas"}
        guid = SecureRandom.uuid
        cp = "urn:fairchampion:testmetadata:individual#{guid}"
        triplify(me, dcat.contactPoint, cp, g)
        triplify(cp, RDF.type, vcard.Individual, g)
        triplify(cp, vcard.fn, i["name"], g) if i["name"]
        next unless i["email"]

        email = i["email"].to_s
        email = "mailto:#{email}" unless email =~ /mailto:/
        triplify(cp, vcard.hasEmail, RDF::URI.new(email), g)
      end

      organizations.each do |o|
        # i = {name: "CBGP", "url": "https://dbdsf.orhf"}
        guid = SecureRandom.uuid
        cp = "urn:fairchampion:testmetadata:org:#{guid}"
        triplify(me, dcat.contactPoint, cp, g)
        triplify(cp, RDF.type, vcard.Organization, g)
        triplify(cp, vcard["organization-name"], o["name"], g)
        triplify(cp, vcard.url, RDF::URI.new(o["url"].to_s), g)
      end

      supportedby.each do |tool|
        triplify(me, ftr.supportedBy, tool, g)
        triplify(tool, RDF.type, schema.SoftwareApplication, g)
      end

      applicationarea.each do |domain|
        triplify(me, ftr.applicationArea, domain, g)
      end
      isapplicablefor.each do |digitalo|
        triplify(me, dpv.isApplicableFor, digitalo, g)
      end

      g
    end
  end
end
