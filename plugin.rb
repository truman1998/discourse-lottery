# name: discourse-lottery
# about: 一个在 Discourse 帖子中创建抽奖的插件。
# version: 1.0.5
# authors: 您的名字 (例如, Truman)
# url: https://github.com/truman1998/discourse-lottery
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

**2. 重建容器**
```bash
cd /var/discourse
./launcher rebuild app
```

**3. 获取并分析完整的错误日志**

容器启动后：
   a. **立即**进入容器并开始监控日志：
      ```bash
      ./launcher enter app
      tail -f /shared/log/rails/production.log
      ```
   b. 在另一个终端或浏览器中，**访问您的论坛首页一次**，以触发 "Oops" 页面。
   c. 回到监控日志的终端，**复制从您访问首页那一刻起（即 `Started GET "/" ...` 日志行）到 `Completed 500 Internal Server Error ...` 之间的所有日志内容。**

   **我们需要找到紧接在 `Completed 500 Internal Server Error` 之前的、详细的 Ruby 错误信息和多行堆栈跟踪 (stack trace)。**

   例如，您应该寻找类似这样的模式：
   ```
   Started GET "/" for [IP_ADDRESS] at [TIMESTAMP]
   Processing by ListController#latest as HTML
   ... (可能有一些正常的日志行) ...
   LotteryPlugin Serializer: EXECUTING for post ID 123, User: some_user  <-- 我们的调试日志
   LotteryPlugin Serializer: Attempting to find lottery for post_id: 123 <-- 我们的调试日志
   LotteryPlugin Serializer: Found lottery #1 for post 123. Title: Sample Lottery <-- 我们的调试日志
   ... (如果序列化器内部出错，这里应该有 "LotteryPlugin Serializer: Error for post ID..." 日志) ...

   ！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
   ！！ 这里是关键：寻找一个大写字母开头的错误，例如 ！！
   ！！   NoMethodError (undefined method `foo' for nil:NilClass):         ！！
   ！！   /var/www/discourse/plugins/discourse-lottery/app/models/....rb:XX:in `some_method' ！！
   ！！   /var/www/discourse/vendor/bundle/ruby/....                     ！！
   ！！   ... (更多堆栈跟踪行) ...                                       ！！
   ！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！

     Rendered layout layouts/application.html.erb (Duration: XXms | GC: XXms)
     Rendered layout layouts/no_ember.html.erb (Duration: XXms | GC: XXms)
   Completed 500 Internal Server Error in XXXms (ActiveRecord: X.Xms | GC: XX.Xms)
     Rendered layout layouts/no_ember.html.erb (Duration: XXms | GC: XXms)
   ```

请您务必提供那段包含实际 Ruby 错误和堆栈跟踪的日志。没有它，我们很难准确判断问题所在。新的日志应该能帮助我们看到序列化器是否被正确执行，以及错误是否发生在
