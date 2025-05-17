# name: discourse-lottery
# about: 一个在 Discourse 帖子中创建抽奖的插件。
# version: 1.0.7
# authors: 您的名字 (例如, Truman)
# url: https://github.com/truman1998/discourse-lottery # <-- 已修正：这里应该是纯文本URL
# required_version: 2.8.0.beta10

# Rails.logger.info "LotteryPlugin: plugin.rb TOP LEVEL - File is being loaded."

enabled_site_setting :lottery_enabled

register_asset "stylesheets/common/lottery.scss"

after_initialize do
  Rails.logger.info "LotteryPlugin: =================== START of after_initialize ==================="
  begin
    module ::LotteryPlugin
      PLUGIN_NAME ||= "discourse-lottery".freeze

      class Engine < ::Rails::Engine
        engine_name PLUGIN_NAME
        isolate_namespace LotteryPlugin
      end
    end
    Rails.logger.info "LotteryPlugin: Engine defined."

    # 确保在这里加载所有依赖，避免 NameError
    require_relative "app/models/lottery_plugin/lottery"
    require_relative "app/models/lottery_plugin/lottery_entry"
    Rails.logger.info "LotteryPlugin: Models loaded (Lottery, LotteryEntry)."

    require_relative "lib/lottery_plugin/parser"
    Rails.logger.info "LotteryPlugin: Parser lib loaded."

    DiscourseEvent.on(:post_process_cooked) do |doc, post|
      begin
        if SiteSetting.lottery_enabled && post && doc && post.persisted? # 确保 post 对象是持久化的
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

    # 修复弃用通知：使用关键字参数 respect_plugin_enabled:
    add_to_serializer(:post, :lottery_data, respect_plugin_enabled: false) do
      # object 是当前的 Post 对象
      # current_user 是当前用户对象 (如果可用)
      post_object = object # 更清晰的变量名
      # Rails.logger.debug "LotteryPlugin Serializer: EXECUTING for post ID #{post_object&.id}, User: #{current_user&.username}"
      begin
        if post_object.nil? || post_object.id.nil?
          # Rails.logger.warn "LotteryPlugin Serializer: Post object or post_object.id is nil. Skipping."
          next nil # 或者 return nil
        end

        # Rails.logger.debug "LotteryPlugin Serializer: Attempting to find lottery for post_id: #{post_object.id}"
        # 确保 LotteryPlugin::Lottery 已正确加载
        lottery = LotteryPlugin::Lottery.find_by(post_id: post_object.id)

        if lottery
          # Rails.logger.debug "LotteryPlugin Serializer: Found lottery ##{lottery.id} for post #{post_object.id}. Title: #{lottery.title}"
          {
            id: lottery.id,
            title: lottery.title,
            prize_name: lottery.prize_name,
            points_cost: lottery.points_cost,
            max_entries: lottery.max_entries,
            total_entries: lottery.entries.count, # 这可能会触发 N+1 查询，但对于调试是可接受的
          }
        else
          # Rails.logger.debug "LotteryPlugin Serializer: No lottery found for post #{post_object.id}"
          nil
        end
      rescue NameError => ne
        # 特别捕获 NameError，因为这通常与类/模块加载有关
        Rails.logger.error "LotteryPlugin Serializer: NameError for post ID #{post_object&.id}. Error: #{ne.class.name} - #{ne.message}\nMisspelled constant or missing require? Backtrace:\n#{ne.backtrace.take(15).join("\n")}"
        nil
      rescue => e
        Rails.logger.error "LotteryPlugin Serializer: GENERIC Error for post ID #{post_object&.id}. Error: #{e.class.name} - #{e.message}\nBacktrace:\n#{e.backtrace.take(15).join("\n")}"
        nil # 在序列化器中出错时返回 nil，以避免破坏整个帖子流
      end
    end
    Rails.logger.info "LotteryPlugin: Serializer for :post added."

  rescue => e # 捕获 after_initialize 块中的任何错误
    Rails.logger.error "LotteryPlugin: =================== FATAL ERROR during after_initialize ===================\nError: #{e.class.name} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
  end
  Rails.logger.info "LotteryPlugin: =================== END of after_initialize ==================="
end

# Rails.logger.info "LotteryPlugin: plugin.rb BOTTOM LEVEL - File loading complete."
```

**关键更改：**
在文件顶部的元数据注释中，将：
`# url: [https://github.com/truman1998/discourse-lottery](https://github.com/truman1998/discourse-lottery)`
修改为：
`# url: https://github.com/truman1998/discourse-lottery`

**接下来的步骤：**

1.  **更新 GitHub 仓库**：
    * 将上面提供的 `plugin.rb` (版本 1.0.7) 的内容替换掉您 GitHub 仓库 (`https://github.com/truman1998/discourse-lottery.git`) 中的 `plugin.rb` 文件。
    * **提交 (Commit) 并推送 (Push) 这个更改**到您的 GitHub 仓库的默认分支 (通常是 `main`)。

2.  **再次确认 GitHub 上的文件**：
    在推送后，请再次访问您 `plugin.rb` 文件的 "Raw" 链接 ([https://raw.githubusercontent.com/truman1998/discourse-lottery/main/plugin.rb](https://raw.githubusercontent.com/truman1998/discourse-lottery/main/plugin.rb))，确保 `url:` 那一行确实已经被修正为纯文本链接。

3.  **重新构建容器**：
    在您的服务器上执行：
    ```bash
    cd /var/discourse
    ./launcher rebuild app
    ```

这次，由于插件元数据应该是正确的，`assets:precompile:build` 阶段的 "Unable to parse plugin name" 错误应该会消失。如果之前的 `TypeError: Cannot read properties of undefined (reading 'cleanup')` 错误是由于元数据解析失败引起的连锁反应，那么它也可能随之解决。

请您仔细操作，特别是确保 GitHub 上的文件内容是正确的。如果构建仍然失败，请提供最新的完整构建
