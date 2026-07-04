const NATIVE_HOST = 'com.clipster.extension';

// 创建顶级菜单
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'clipster-root',
    title: '从 Clipster 粘贴',
    contexts: ['editable', 'page']
  });

  chrome.contextMenus.create({
    id: 'clipster-refresh',
    title: '刷新列表',
    parentId: 'clipster-root',
    contexts: ['editable', 'page']
  });
});

// 点击菜单时处理
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'clipster-refresh') {
    await refreshMenu();
    return;
  }

  if (info.menuItemId.startsWith('clipster-item:')) {
    const content = info.menuItemId.slice('clipster-item:'.length);
    try {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id, frameIds: [info.frameId || 0] },
        func: (text) => {
          const el = document.activeElement;
          if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable)) {
            if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
              const start = el.selectionStart || 0;
              const end = el.selectionEnd || 0;
              el.value = el.value.slice(0, start) + text + el.value.slice(end);
              el.selectionStart = el.selectionEnd = start + text.length;
            } else {
              document.execCommand('insertText', false, text);
            }
            el.focus();
          } else {
            // 没有聚焦输入框时写入剪贴板
            navigator.clipboard.writeText(text);
          }
        },
        args: [content]
      });
    } catch (err) {
      console.error('Clipster paste failed:', err);
    }
  }
});

// 每次右键显示菜单前刷新列表
chrome.contextMenus.onShown.addListener(async () => {
  await refreshMenu();
});

async function refreshMenu() {
  try {
    const port = chrome.runtime.connectNative(NATIVE_HOST);
    let resolved = false;

    const timeout = setTimeout(() => {
      if (!resolved) {
        port.disconnect();
        updateMenuItems([]);
      }
    }, 1500);

    port.onMessage.addListener((msg) => {
      clearTimeout(timeout);
      resolved = true;
      if (msg && Array.isArray(msg.items)) {
        updateMenuItems(msg.items);
      }
      port.disconnect();
    });

    port.onDisconnect.addListener(() => {
      clearTimeout(timeout);
      if (!resolved) {
        updateMenuItems([]);
      }
    });

    port.postMessage({ action: 'list', limit: 20 });
  } catch (err) {
    console.error('Clipster native messaging error:', err);
    updateMenuItems([]);
  }
}

function updateMenuItems(items) {
  // 移除旧的条目菜单
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'clipster-root',
      title: '从 Clipster 粘贴',
      contexts: ['editable', 'page']
    });

    if (!items || items.length === 0) {
      chrome.contextMenus.create({
        id: 'clipster-empty',
        title: '暂无内容',
        parentId: 'clipster-root',
        contexts: ['editable', 'page'],
        enabled: false
      });
      chrome.contextMenus.create({
        id: 'clipster-refresh',
        title: '刷新列表',
        parentId: 'clipster-root',
        contexts: ['editable', 'page']
      });
      return;
    }

    items.forEach((item, index) => {
      const title = truncate(item.title || item.content || '无内容', 40);
      chrome.contextMenus.create({
        id: `clipster-item:${item.content}`,
        title: title,
        parentId: 'clipster-root',
        contexts: ['editable', 'page']
      });
    });

    chrome.contextMenus.create({ id: 'clipster-sep', type: 'separator', parentId: 'clipster-root', contexts: ['editable', 'page'] });
    chrome.contextMenus.create({
      id: 'clipster-refresh',
      title: '刷新列表',
      parentId: 'clipster-root',
      contexts: ['editable', 'page']
    });
  });
}

function truncate(str, max) {
  if (!str) return '';
  return str.length > max ? str.slice(0, max) + '…' : str;
}
