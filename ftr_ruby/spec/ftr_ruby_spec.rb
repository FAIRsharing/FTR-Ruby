# frozen_string_literal: true

require "spec_helper"

RSpec.describe FtrRuby do
  it "has a version number" do
    expect(FtrRuby::VERSION).not_to be nil
  end
end
