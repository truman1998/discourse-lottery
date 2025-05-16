import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n"; // 确保导入 I18n
// import { h } from "virtual-dom"; // 如果需要用 virtual-dom 创建元素

export default apiInitializer("1.0.1", (api) => { // 版本化您的初始化器
  // 使用 Discourse 的模态服务显示警报的辅助函数
  const showAlert = (message, type = 'error') => {
    const modal = api.container.lookup("service:modal");
    if (modal && modal.alert) {
      modal.alert({ message, type }); // type 可以是 'error', 'success', 'warning'
    } else {
      window.alert(message); // 回退
    }
  };

  // 更新抽奖框状态显示的函数
  function updateStatusDisplay(box, currentEntries, maxEntries, prizeName, pointsCost) {
    const statusDiv = box.querySelector(".lottery-status-display");
    if (!statusDiv) return;

    let entriesText;
    if (maxEntries && maxEntries > 0) {
      const remaining = Math.max(0, maxEntries - currentEntries);
      entriesText = I18n.t("js.lottery.status_limited", {
        current: currentEntries,
        total: maxEntries,
        remaining: remaining,
      });
    } else {
      entriesText = I18n.t("js.lottery.status_unlimited", { count: currentEntries });
    }

    const costText = pointsCost > 0 ? I18n.t("js.lottery.cost_info", { cost: pointsCost }) : I18n.t("js.lottery.cost_free");

    statusDiv.innerHTML = ''; // 清除现有内容

    const prizeElement = document.createElement("div");
    prizeElement.className = "lottery-prize";
    prizeElement.textContent = I18n.t("js.lottery.prize", { prizeName: prizeName || I18n.t("js.lottery.default_prize") });

    const statsElement = document.createElement("div");
    statsElement.className = "lottery-stats";
    statsElement.textContent = entriesText;

    const costElement = document.createElement("div");
    costElement.className = "lottery-cost";
    costElement.textContent = costText;

    statusDiv.append(prizeElement, statsElement, costElement);
  }


  api.decorateCookedElement((cookedElem, postDecorator) => {
    if (!postDecorator) return;

    const post = postDecorator.getModel();
    if (!post || !post.id) return;

    const lotteryData = post.lottery_data;

    if (lotteryData && lotteryData.id) {
      let lotteryBox = cookedElem.querySelector(`.lottery-box[data-lottery-id="${lotteryData.id}"]`);

      if (!lotteryBox) {
         let placeholder = cookedElem.querySelector('.lottery-placeholder-for-post-' + post.id);
         if (!placeholder) {
            placeholder = document.createElement('div');
            // 给这个自动创建的 div 一个更明确的类名，以便调试和可能的特定样式
            placeholder.className = `lottery-box auto-created-lottery-box lottery-placeholder-for-post-${post.id}`;
            cookedElem.appendChild(placeholder);
         }
         lotteryBox = placeholder;
         lotteryBox.dataset.lotteryId = lotteryData.id;
      }

      if (lotteryBox.dataset.lotteryInitialized === "true") return;
      lotteryBox.dataset.lotteryInitialized = "true";

      lotteryBox.dataset.prizeName = lotteryData.prize_name || I18n.t("js.lottery.default_prize");
      lotteryBox.dataset.pointsCost = lotteryData.points_cost;
      lotteryBox.dataset.maxEntries = lotteryData.max_entries || "";
      lotteryBox.dataset.totalEntries = lotteryData.total_entries;
      lotteryBox.dataset.lotteryTitle = lotteryData.title || I18n.t("js.lottery.default_title");

      lotteryBox.innerHTML = ''; // 清除占位符内容

      const lotteryId = lotteryData.id;
      const cost = parseInt(lotteryData.points_cost, 10) || 0;
      const maxEntries = lotteryData.max_entries ? parseInt(lotteryData.max_entries, 10) : null;
      let currentEntries = parseInt(lotteryData.total_entries, 10) || 0;
      const prizeName = lotteryData.prize_name;
      const lotteryTitle = lotteryData.title;

      const container = document.createElement("div");
      container.className = "lottery-ui-container";

      const titleElement = document.createElement("h3");
      titleElement.className = "lottery-title-display";
      titleElement.textContent = lotteryTitle || I18n.t("js.lottery.default_title");
      container.appendChild(titleElement);

      const statusDisplay = document.createElement("div");
      statusDisplay.className = "lottery-status-display";
      container.appendChild(statusDisplay);

      updateStatusDisplay(lotteryBox, currentEntries, maxEntries, prizeName, cost);

      const button = document.createElement("button");
      button.className = "btn btn-primary join-lottery-btn";
      button.innerHTML = cost > 0
        ? I18n.t("js.lottery.participate_with_cost_btn", { cost })
        : I18n.t("js.lottery.participate_btn");

      if (maxEntries && currentEntries >= maxEntries) {
        button.disabled = true;
        button.innerHTML = I18n.t("js.lottery.max_entries_reached_btn");
      }

      const messageArea = document.createElement("div");
      messageArea.className = "lottery-message-area";
      // container.appendChild(messageArea); // 移动到按钮之后添加

      button.addEventListener("click", async () => {
        if (cost > 0) {
          const modal = api.container.lookup("service:modal");
          modal.confirm({
            message: I18n.t("js.lottery.confirm_cost_participation", { cost }),
            didConfirm: async () => {
              await tryJoinLottery();
            }
          });
        } else {
          await tryJoinLottery();
        }
      });

      async function tryJoinLottery() {
        button.disabled = true;
        messageArea.textContent = I18n.t("js.lottery.joining");
        messageArea.className = "lottery-message-area lottery-processing";

        try {
          // 使用 api.container.lookup("service:csrf").token 获取 CSRF token
          const csrfService = api.container.lookup("service:csrf");
          const token = csrfService ? csrfService.token : null;

          if (!token) {
            // 这个错误消息最好也通过 I18n 处理
            throw new Error(I18n.t("js.lottery.csrf_token_error"));
          }

          const response = await fetch("/lottery_plugin/entries", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": token,
            },
            body: JSON.stringify({ lottery_id: lotteryId }),
          });

          const data = await response.json();

          if (response.ok && data.success) {
            showAlert(data.message || I18n.t("js.lottery.success_joined_alert"), 'success');
            currentEntries = data.total_entries;
            lotteryBox.dataset.totalEntries = currentEntries;
            updateStatusDisplay(lotteryBox, currentEntries, maxEntries, prizeName, cost);

            if (maxEntries && currentEntries >= maxEntries) {
              button.disabled = true;
              button.innerHTML = I18n.t("js.lottery.max_entries_reached_btn");
            }
            messageArea.textContent = I18n.t("js.lottery.success_message_inline");
            messageArea.className = "lottery-message-area lottery-success";
          } else {
            const errorMessage = data.error || (data.errors && data.errors.join(", ")) || I18n.t("js.lottery.generic_error_client");
            showAlert(errorMessage, 'error');
            messageArea.textContent = errorMessage;
            messageArea.className = "lottery-message-area lottery-error";
            // 只有在不是因为“已参与”或“已满”的错误时才重新启用按钮
            if (response.status !== 403 && response.status !== 422 && !(data.error && data.error.includes(I18n.t("lottery.errors.already_participated")))) {
                 button.disabled = false;
            }
          }
        } catch (e) {
          console.error("Lottery Plugin JS Error:", e);
          const networkErrorMsg = I18n.t("js.lottery.network_error_client");
          showAlert(networkErrorMsg + (e.message ? ` (${e.message})` : ''), 'error');
          messageArea.textContent = networkErrorMsg;
          messageArea.className = "lottery-message-area lottery-error";
          button.disabled = false;
        }
      }

      lotteryBox.appendChild(container);
      // 仅当抽奖尚未满员时才添加按钮
      // 并且，如果服务器端逻辑正确，用户不应该看到按钮如果他们已经参与 (这需要更复杂的 has_entered 逻辑)
      if (! (maxEntries && currentEntries >= maxEntries) ) {
        container.appendChild(button);
      }
      container.appendChild(messageArea); // 消息区域在按钮之后

    }
  }, {
    id: 'discourse-lottery-decorator',
    onlyStream: true
  });
});
