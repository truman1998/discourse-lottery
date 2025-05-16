# Discourse 抽奖插件

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![版本: 1.0.2](https://img.shields.io/badge/version-1.0.2-blue.svg)](https://github.com/truman1998/discourse-lottery)
[![Discourse 版本: 2.8.0.beta10+](https://img.shields.io/badge/Discourse-2.8.0.beta10%2B-brightgreen.svg)](https://www.discourse.org/)

一个为 Discourse 设计的专业抽奖系统插件，允许您在社区内创建互动式的抽奖和赠品活动。此插件支持使用积分参与、设置参与人数限制，并提供实时统计数据。

## 功能特性

- 🎉 **帖子内嵌抽奖**: 轻松在 Discourse 帖子中创建和嵌入抽奖活动。
- 💰 **基于积分的参与**: 可选功能，要求用户花费积分才能参与抽奖。
- 🛑 **参与人数限制**: 为每次抽奖设置最大参与人数。
- 📊 **实时统计**: 显示当前的参与人数和剩余名额。
- 🔒 **防止重复参与**: 自动阻止用户重复参与同一次抽奖。
- 🌍 **多语言支持**: 内置英文和简体中文翻译。
- 🎨 **可定制外观**: 提供基础样式，易于扩展。

## 工作原理 (简要概述)

1.  **创建抽奖**: 管理员或有权限的用户可以通过在帖子中添加特殊标记来创建抽奖（此机制的细节将在 `parser.rb` 和相关文档中定义，例如，使用像 `[lottery prize="新小玩意" cost="10" max_entries="100"]` 这样的 BBCode）。
2.  **显示**: 插件检测到这些标记，并在帖子中渲染一个互动的抽奖框。
3.  **参与**: 用户可以点击按钮加入。如果需要积分，则会扣除相应积分。
4.  **限制**: 系统强制执行最大参与人数限制并防止重复参与。
5.  **反馈**: 用户会立即收到其参与状态的反馈。

*(注意: `lib/lottery_plugin/parser.rb` 中用于从帖子内容创建抽奖的实际解析逻辑需要根据您期望的语法（例如 BBCode 或特定的 Markdown 结构）进行完整实现。当前提供的是一个基本占位符。)*

## 安装步骤

1.  **访问您的 Discourse 服务器**: 通过 SSH 登录到您的 Discourse 服务器。
2.  **导航到插件目录**: `cd /var/discourse/plugins` (或您特定的 Discourse 插件路径)。
3.  **克隆仓库 (如果尚未克隆)**:
    ```bash
    git clone [https://github.com/truman1998/discourse-lottery.git](https://github.com/truman1998/discourse-lottery.git)
    ```
    如果您已经克隆了，请确保更新到最新版本。
4.  **重建您的 Discourse 应用**:
    ```bash
    cd /var/discourse
    ./launcher rebuild app
    ```
5.  **启用插件**: 在您的 Discourse 管理设置中，找到“抽奖”并确保“启用抽奖插件”已被勾选。

## 配置

- **站点设置**:
    - `lottery_enabled`: 在全站范围内启用或禁用抽奖插件。(位于 管理 -> 设置 -> 插件)

## 开发说明

- **模型 (Models)**:
    - `LotteryPlugin::Lottery`: 存储抽奖详情 (帖子, 奖品, 消耗, 最大参与人数)。
    - `LotteryPlugin::LotteryEntry`: 记录用户参与情况。
- **控制器 (Controller)**:
    - `LotteryPlugin::EntriesController`: 处理用户参与抽奖的请求。
- **前端 (Frontend)**:
    - `lottery.js.es6`: 管理抽奖框的互动元素。
    - `lottery.scss`: 为抽奖框提供样式。
- **本地化 (Localization)**:
    - `en.yml`, `zh_CN.yml` (服务器端) 和 `client.en.yml`, `client.zh_CN.yml` (客户端) 为 UI 元素提供翻译。

## 问题排查

- **"Oops" 页面**: 如果安装或更新后看到 "Oops" 页面，请检查服务器上的 `/var/discourse/shared/standalone/log/rails/production.log` (或通过 `./launcher enter app` 进入容器后查看 `log/production.log` 或 `log/unicorn.stderr.log`) 以获取详细的 Ruby 错误信息。常见原因包括：
    - 插件文件中的 Ruby 语法错误或 `NameError` (例如，类或模块名称不正确)。
    - 文件缺失或命名不正确 (特别是迁移文件、模型或本地化文件)。
    - 数据库迁移问题 (尽管您的日志显示迁移已运行)。
    - `parser.rb` 逻辑中的问题。
- **按钮不出现/不工作**: 检查浏览器的开发者控制台是否有 JavaScript 错误。确保插件的 JavaScript 和 CSS 资源已正确加载。

## 贡献

欢迎提交贡献、报告问题和提出功能请求！请随时查看 [issues 页面](https://github.com/truman1998/discourse-lottery/issues)。

## 许可证

该插件根据 [MIT 许可证](https://opensource.org/licenses/MIT) 的条款作为开源软件提供。
