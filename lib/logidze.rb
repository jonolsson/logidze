# frozen_string_literal: true

require "logidze/version"

# Logidze provides tools for adding in-table JSON-based audit to DB tables
# and ActiveRecord extensions to work with changes history.
module Logidze
  require "logidze/history"
  require "logidze/model"
  require "logidze/model/time_helper"
  require "logidze/model/sequel"
  # require "logidze/versioned_association"
  require "logidze/ignore_log_data"
  require "logidze/has_logidze"
  # require "logidze/meta"
  require "logidze/connection_adapter/base"
  require "logidze/connection_adapter/sequel"

  # extend Logidze::Meta

  require "logidze/engine" if defined?(Rails)

  class << self
    attr_accessor :default_connection_adapter
    # Determines if Logidze should append a version to the log after updating an old version.
    attr_accessor :append_on_undo
    # Determines whether associations versioning is enabled or not
    attr_accessor :associations_versioning
    # Determines if Logidze should exclude log data from SELECT statements
    attr_accessor :ignore_log_data_by_default
    # Whether #at should return self or nil when log_data is nil
    attr_accessor :return_self_if_log_data_is_empty
    # Determines if triggers are sorted by related table id or by name
    attr_accessor :sort_triggers_by_name
    # Determines what Logidze should do when upgrade is needed (:raise | :warn | :ignore)
    attr_reader :on_pending_upgrade

    def on_pending_upgrade=(mode)
      if !%i[raise warn ignore].include? mode
        raise ArgumentError,
          "Unknown on_pending_upgrade option `#{mode.inspect}`. Expecting :raise, :warn or :ignore"
      end
      @on_pending_upgrade = mode
    end

    # CONNECTION_ADAPTERS = {active_record: ConnectionAdapter::ActiveRecord, sequel: ConnectionAdapter::Sequel}.freeze
    CONNECTION_ADAPTERS = {sequel: ConnectionAdapter::Sequel}.freeze

    # Access connection adapter for manupulations.
    #
    # @example
    #   Logidze[:active_record].without_logging { Post.update_all(active: true) }
    def [](connection_adapter)
      CONNECTION_ADAPTERS.fetch(connection_adapter.to_sym)
    end
    
    # Temporary disable DB triggers.
    #
    # @example
    #   Logidze.without_logging { Post.update_all(active: true) }
    def without_logging(&block)
      # with_logidze_setting("logidze.disabled", "on") { yield }
      self[default_connection_adapter].without_logging(&block)
    end

    # Instruct Logidze to create a full snapshot for the new versions, not a diff
    #
    # @example
    #   Logidze.with_full_snapshot { post.touch }
    def with_full_snapshot(&block)
      self[default_connection_adapter].with_full_snapshot(&block)
      # with_logidze_setting("logidze.full_snapshot", "on") { yield }
    end

    # Store special meta information about changes' author inside the version (Responsible ID).
    # Usually, you would like to store the `current_user.id` that way
    # (default connection adapter).
    #
    # @example
    #   Logidze.with_responsible(user.id) { post.save! }
    def with_responsible(responsible_id, transactional: true, &block)
      self[default_connection_adapter].with_responsible(responsible_id, transactional: transactional, &block)
    end

    # def on_pending_upgrade=(mode)
    #   if %i[raise warn ignore].exclude? mode
    #     raise ArgumentError, "Unknown on_pending_upgrade option `#{mode.inspect}`. Expecting :raise, :warn or :ignore"
    #   end
    #   @on_pending_upgrade = mode
    # end

    # private

    # def with_logidze_setting(name, value)
    #   ActiveRecord::Base.transaction do
    #     ActiveRecord::Base.connection.execute "SET LOCAL #{name} TO #{value};"
    #     res = yield
    #     ActiveRecord::Base.connection.execute "SET LOCAL #{name} TO DEFAULT;"
    #     res
    #   end
    # end
  end

  self.default_connection_adapter = :sequel
  self.append_on_undo = false
  self.associations_versioning = false
  self.ignore_log_data_by_default = false
  self.return_self_if_log_data_is_empty = true
  self.on_pending_upgrade = :ignore
  self.sort_triggers_by_name = false
end
