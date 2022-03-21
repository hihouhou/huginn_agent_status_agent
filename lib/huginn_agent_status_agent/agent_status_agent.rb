module Agents
  class AgentStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_5m'

    description do
      <<-MD
      The huginn agent status creates an event when an agent has status "not working".

      `debug` is used to verbose mode.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "id"=>46,
            "user_id"=>1,
            "type"=>"Agents::ActivisionGamesStatusAgent",
            "name"=>"test",
            "schedule"=>"never",
            "guid"=>"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean
    def validate_options

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_status
    end

    private

    def check_status()

      client = Mysql2::Client.new(
              :host     => "#{ENV['DATABASE_HOST']}",
              :username => "#{ENV['DATABASE_USERNAME']}",
              :password => "#{ENV['DATABASE_PASSWORD']}",
              :database => "#{ENV['DATABASE_NAME']}",
              :encoding => "#{ENV['DATABASE_ENCODING']}"
              )
      results = client.query("select id,user_id,type,name,schedule,guid from agents where disabled = 0 and ((last_check_at IS NOT NULL and JSON_EXTRACT(options, '$.expected_receive_period_in_days') IS NOT NULL and last_event_at <= NOW() - INTERVAL JSON_EXTRACT(options, '$.expected_receive_period_in_days') DAY) OR (JSON_EXTRACT(options, '$.expected_update_period_in_days') IS NOT NULL and last_event_at <= NOW() - INTERVAL JSON_EXTRACT(options, '$.expected_update_period_in_days') DAY)) order by id desc")
      payload = []
      results.each do |row|
        payload.push row
      end


      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload.each do |agent|
              create_event payload: agent
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload.each do |agent|
              found = false
              if interpolated['debug'] == 'true'
                log "agent"
                log agent
              end
              last_status.each do |agentbis|
                if agent == agentbis
                  found = true
                end
              end
              if found == false
                if interpolated['debug'] == 'true'
                  log "found is #{found}! so event created"
                  log agent
                end
                create_event payload: agent
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
