require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::AgentStatusAgent do
  before(:each) do
    @valid_options = Agents::AgentStatusAgent.new.default_options
    @checker = Agents::AgentStatusAgent.new(:name => "AgentStatusAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
