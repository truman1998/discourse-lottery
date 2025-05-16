# name: discourse-lottery
# about: 一个在 Discourse 帖子中创建抽奖的插件。
# version: 1.0.4
# authors: 您的名字 (例如, Truman)
# url: https://github.com/truman1998/discourse-lottery
# required_version: 2.8.0.beta10

# Rails.logger.info "LotteryPlugin: plugin.rb TOP LEVEL - File is being loaded."

enabled_site_setting :lottery_enabled

register_asset "stylesheets/common/lottery.scss"

after_initialize do
  Rails.logger.info "LotteryPlugin: START of after_initialize block."
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
    Rails.logger.info "LotteryPlugin: Models loaded."

    require_relative "lib/lottery_plugin/parser"
    Rails.logger.info "LotteryPlugin: Parser lib loaded."

    DiscourseEvent.on(:post_process_cooked) do |doc, post|
      begin
        if SiteSetting.lottery_enabled && post && doc
          # Rails.logger.debug "LotteryPlugin: [Event :post_process_cooked] Processing post ID #{post.id}."
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

    add_to_serializer(:post, :lottery_data, false) do
      begin
        # Rails.logger.debug "LotteryPlugin Serializer: Checking post ID #{object.id}"
        lottery = LotteryPlugin::Lottery.find_by(post_id: object.id)
        if lottery
          # Rails.logger.debug "LotteryPlugin Serializer: Found lottery ##{lottery.id} for post #{object.id}"
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
      rescue => e
        Rails.logger.error "LotteryPlugin Serializer: Error for post ID #{object&.id}. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.take(10).join("\n")}"
        nil
      end
    end
    Rails.logger.info "LotteryPlugin: Serializer for :post added."

  rescue => e
    Rails.logger.error "LotteryPlugin: FATAL ERROR during after_initialize. Error: #{e.class.name} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
  end
  Rails.logger.info "LotteryPlugin: END of after_initialize block."
end

# Rails.logger.info "LotteryPlugin: plugin.rb BOTTOM LEVEL - File loading complete."
