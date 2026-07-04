# Clipster

Clipster 是一款为 macOS 设计的剪贴板历史管理工具。它把系统剪贴板升级成一个可搜索、可分类、可分组、支持全局快捷键的现代化粘贴板，并附带 Chrome 扩展，让你在网页输入框中也能快速调用历史记录。

## 功能特性

- **自动记录剪贴板**：监听系统剪贴板变化，自动保存文本、链接、图片、代码片段。
- **分类展示**：支持「全部 / 文本 / 链接 / 图片 / 代码 / 收藏 / 私密」等分类，图片使用九宫格布局。
- **自定义分组**：可创建多个分组，将跨分类的条目归入同一组，方便按项目或场景组织。
- **全文搜索**：基于 SQLite FTS5 实现快速搜索。
- **全局快捷键**：
  - `⌃⌘M` 唤出 / 隐藏 Clipster 面板
  - `⌘G` 将选中条目加入分组
  - `⌘D` 收藏 / 取消收藏
  - 数字键 `1-8` 快速粘贴前 8 条
- **右键级联菜单**：在 Clipster 列表中右键 →「加入分组」→ 展开所有分组，一键切换归属。
- **Chrome 扩展**：在网页输入框右键 →「从 Clipster 粘贴」→ 选择历史记录直接插入。
- **自动清理**：默认只保留最近 7 天数据，防止数据库无限膨胀。
- **去重与收藏**：自动去重，支持收藏常用内容。

## 安装与运行

### 方式一：直接运行已构建的 App

```bash
git clone git@github.com:hechenglo03/clipster.git
cd clipster
open Clipster.app
```

首次运行时，系统会提示授权：

1. **系统设置 → 隐私与安全性 → 输入监控** → 添加并勾选 `Clipster.app`
2. **系统设置 → 隐私与安全性 → 辅助功能** → 添加并勾选 `Clipster.app`（如提示）

> 注意：开发阶段使用 ad-hoc 签名，每次重新编译后可能需要重新授权。后续发布到 Mac App Store 或使用正式开发者证书签名后可避免此问题。

### 方式二：从源码构建

依赖：macOS 11.0+、Xcode Command Line Tools

```bash
./build-app.sh
open Clipster.app
```

构建脚本会：
1. 使用 `swiftc` 直接编译所有 Swift 源文件
2. 打包成 `Clipster.app`
3. 进行 ad-hoc 代码签名

## 使用说明

### 主面板

- 按 `⌃⌘M` 唤出 Clipster 浮层面板。
- 使用 `↑` / `↓` 选择条目，`↩` 粘贴。
- 在输入框中输入 `/` 聚焦搜索框。
- 左侧边栏切换分类或分组。

### 分组管理

- 侧栏「我的分组」标题右侧点击可新建分组。
- 选中条目后按 `⌘G`，或右键选择「加入分组」。
- 分组支持右键「编辑 / 删除」，删除分组不会删除条目。

### Chrome 扩展

1. 打开 Chrome，访问 `chrome://extensions/`
2. 开启右上角「开发者模式」
3. 点击「加载已解压的扩展程序」，选择 `ChromeExtension` 文件夹
4. 运行一次 `./ChromeExtension/install-host.sh` 注册原生消息主机
5. 在任意网页输入框右键即可看到「从 Clipster 粘贴」

## 项目结构

```
clipster/
├── Clipster.app/                  # 构建好的 macOS 应用
├── Sources/Clipster/
│   ├── App/                       # AppDelegate、main
│   ├── Models/                    # 数据模型：ClipItem、ClipGroup、Category
│   ├── Data/                      # SQLite 数据库与 Repository
│   ├── Domain/                    # 剪贴板监听、分类、去重、搜索
│   ├── OSBridge/                  # 全局热键、粘贴模拟、系统权限
│   ├── NativeMessaging/           # Chrome 扩展原生消息通信
│   └── Presentation/              # AppKit UI：面板、列表、设置、菜单栏
├── ChromeExtension/               # Chrome 扩展源码
├── build-app.sh                   # 编译打包脚本
├── product-design.html            # 产品方案
├── tech-design.html               # 技术方案
└── *.html                         # 各功能设计文档
```

## 技术栈

- **语言**：Swift
- **UI 框架**：AppKit（原生 macOS）
- **数据库**：SQLite3 + FTS5
- **热键**：Carbon / CGEventTap
- **原生消息**：Chrome Native Messaging
- **构建**：`swiftc` + Shell 脚本

## 数据存储

- 数据库文件：`~/Library/Application Support/Clipster/clipster.sqlite`
- 图片缓存：`~/Library/Application Support/Clipster/images/`
- 默认保留最近 7 天数据，收藏内容不会被清理。

## 已知限制

- 开发阶段使用 ad-hoc 签名，每次重新编译后系统权限可能失效，需要重新授权。
- Chrome 扩展目前仅支持 Chromium 内核浏览器（Chrome、Edge、Brave 等），不支持 Safari。

## 贡献

欢迎提 Issue 或 PR。

## License

MIT
