# frozen_string_literal: true

require "sequel/model"

require "logidze"
require "logidze/history/serializer"

module Sequel
  module Plugins
    # A standard Sequel plugin which replicates `has_logidze` method from ActiveRecord
    module Logidze
      def self.configure(model, opts = {})
        model.instance_eval do
          @ignore_log_data = opts.fetch(:ignore_log_data) do
            ::Logidze.ignore_log_data_by_default
          end

          if @ignore_log_data
            plugin :lazy_attributes, :log_data
            plugin :insert_returning_select
          end
        end
      end

      module DatasetMethods
        include ::Logidze::Model::ClassMethods

        def logidze_connection_adapter
          ::Logidze::Model::SequelModel
        end

        def ignores_log_data?
          @ignore_log_data
        end

        def with_log_data
          all_selectd_columns = columns.map { |column| Sequel.qualify(first_source, column) }
          selected_columns = opts[:select]

          if all_selectd_columns == selected_columns
            select_all
          else
            select(*selected_columns + [Sequel.qualify(first_source, :log_data)])
          end
        end
      end

      module ClassMethods
        Sequel::Plugins.def_dataset_methods(self, %i[
          logidze_connection_adapter
          ignores_log_data?
          with_log_data
          has_logidze
          at
          diff_from
          without_logging
          reset_log_data
          create_logidze_snapshot
        ])
        Sequel::Plugins.inherited_instance_variables(self, :@ignore_log_data => :dup)
      end

      module InstanceMethods
        include ::Logidze::Model

        def logidze_connection_adapter
          @logidze_connection_adapter ||= ::Logidze::Model::SequelModel.new(self)
        end

        # TODO: use `serialization` plugin later as it seems the setter doesn't work without reload.
        def log_data
          @deserialized_log_data ||= ::Logidze::History::Serializer.deserialize(self[:log_data])
        end

        def log_data=(value)
          self[:log_data] = ::Logidze::History::Serializer.serialize(value)
          @deserialized_log_data = nil
          log_data
        end

        # Called on `dup`.
        def initialize_copy(other)
          super
          self.log_data = other.log_data.dup
          self
        end

        # Called on model's manual find.
        def _refresh_set_values(values)
          result = super
          @deserialized_log_data = nil
          result
        end

        # Called on model's auto find.
        def _save_set_values(values)
          result = super
          @deserialized_log_data = nil
          result
        end
      end
    end
  end
end
# # frozen_string_literal: true
#
# module Sequel
#   module Plugins
#     module Logidze
#       def self.apply(model)
#         model.instance_eval do
#           plugin(:after_initialize)
#         end
#       end
#
#       module InstanceMethods
#         def after_initialize
#           super
#           self.log_data = ::Logidze::History.new(log_data)
#         end
#
#         def before_save
#           self.log_data = self.log_data.data
#           super
#         end
#
#         include ::Logidze::Model
#         delegate :version, to: :log_data
#         delegate :version, to: :log_data, prefix: :log
#       end
#     end
#   end
# end
