# name: discourse-lottery
# about: A Discourse plugin to create and manage lotteries.
# version: 1.0.9
# authors: Truman
# url: https://github.com/truman1998/discourse-lottery
# required_version: 2.8.0.beta10

enabled_site_setting :lottery_enabled

register_asset "stylesheets/common/lottery.scss"

after_initialize do
  Rails.logger.info "LotteryPlugin: =================== START of after_initialize (v1.0.9) ==================="
  begin
    module ::LotteryPlugin
      PLUGIN_NAME ||= "discourse-lottery".freeze

      class Engine < ::Rails::Engine
        engine_name PLUGIN_NAME
        isolate_namespace LotteryPlugin
      end
    end
    Rails.logger.info "LotteryPlugin: Engine defined."

    require_relative "app/models/lottery_plugin/lottery"
    require_relative "app/models/lottery_plugin/lottery_entry"
    Rails.logger.info "LotteryPlugin: Models loaded (Lottery, LotteryEntry)."

    require_relative "lib/lottery_plugin/parser"
    Rails.logger.info "LotteryPlugin: Parser lib loaded."

    DiscourseEvent.on(:post_process_cooked) do |doc, post|
      begin
        if SiteSetting.lottery_enabled && post && doc && post.persisted?
          LotteryPlugin::Parser.parse(post, doc)
        end
      rescue => e
        Rails.logger.error "LotteryPlugin: [Event :post_process_cooked] Error processing post ID #{post&.id}. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.take(10).join("\n")}"
      end
    end
    Rails.logger.info "LotteryPlugin: :post_process_cooked event handler registered."

    require_dependency File.expand_path("../app/controllers/lottery_plugin/entries_controller.rb", __FILE__)
    Rails.logger.info "LotteryPlugin: EntriesController loaded."

    LotteryPlugin::Engine.routes.draw do
      post "/entries" => "entries#create"
    end
    Rails.logger.info "LotteryPlugin: Engine routes drawn."

    Discourse::Application.routes.append do
      mount ::LotteryPlugin::Engine, at: "/lottery_plugin"
    end
    Rails.logger.info "LotteryPlugin: Engine mounted into Application routes."

    add_to_serializer(:post, :lottery_data, respect_plugin_enabled: false) do
      post_object = object
      begin
        if post_object.nil? || post_object.id.nil?
          next nil
        end
        lottery = LotteryPlugin::Lottery.find_by(post_id: post_object.id)
        if lottery
          {
            id: lottery.id,
            title: lottery.title,
            prize_name: lottery.prize_name,
            points_cost: lottery.points_cost,
            max_entries: lottery.max_entries,
            total_entries: lottery.entries.count,
          }
        else
          nil
        end
      rescue NameError => ne
        Rails.logger.error "LotteryPlugin Serializer: NameError for post ID #{post_object&.id}. Error: #{ne.class.name} - #{ne.message}\nMisspelled constant or missing require? Backtrace:\n#{ne.backtrace.take(15).join("\n")}"
        nil
      rescue => e
        Rails.logger.error "LotteryPlugin Serializer: GENERIC Error for post ID #{post_object&.id}. Error: #{e.class.name} - #{e.message}\nBacktrace:\n#{e.backtrace.take(15).join("\n")}"
        nil
      end
    end
    Rails.logger.info "LotteryPlugin: Serializer for :post added."

  rescue => e
    Rails.logger.error "LotteryPlugin: =================== FATAL ERROR during after_initialize ===================\nError: #{e.class.name} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
  end
  Rails.logger.info "LotteryPlugin: =================== END of after_initialize (v1.0.9) ==================="
end
