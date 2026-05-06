# AppOrganizer MVP 项目说明

## 项目背景

`AppOrganizer` 是一个面向 macOS 的本地应用整理工具，目标是帮助用户将已安装应用按分类进行管理与浏览。  
项目当前定位为 **本机自用 MVP**，不依赖云端服务，不考虑上架流程，优先实现高频使用功能与快速迭代。

核心需求：
- 支持手动新建、编辑、删除分类
- 支持应用在分类中的归类与移除
- 支持自动整理（基于应用名称与 Bundle ID 的关键词规则）
- 支持分类拖动排序
- 数据持久化在本机 JSON 文件中

当前数据文件路径：
- `~/Library/Application Support/AppOrganizer/library.json`

---

## 代码架构

项目采用 **SwiftUI + MVVM（轻量）**，通过 Swift Package Manager 组织源码。

### 目录结构

- `Package.swift`
  - Swift 包配置，指定 macOS 平台与可执行 target
- `Sources/AppOrganizer/AppOrganizerApp.swift`
  - 应用入口（`@main`），创建主窗口并注入 `OrganizerViewModel`
- `Sources/AppOrganizer/ContentView.swift`
  - 主界面与交互逻辑（侧边分类、详情网格、弹窗、提示、拖拽）
- `Sources/AppOrganizer/OrganizerViewModel.swift`
  - 核心业务逻辑与状态管理（分类管理、自动整理、保存）
- `Sources/AppOrganizer/AppScanner.swift`
  - 扫描系统应用目录并构建应用清单；负责打开应用
- `Sources/AppOrganizer/Models.swift`
  - 数据模型定义（`CategoryRecord`、`AppDatabase`、`InstalledApp`）
- `Sources/AppOrganizer/JSONStore.swift`
  - JSON 持久化读写（Application Support 下的 `library.json`）
- `Resources/Info.plist`
  - `.app` 打包所需基础元数据
- `bundle-app.sh`
  - 一键构建并组装 `.app` 包脚本（输出到 `dist/`）

### 架构说明

- **View 层（SwiftUI）**
  - 负责界面展示与交互触发
  - 通过 `@EnvironmentObject` 使用 `OrganizerViewModel`
- **ViewModel 层**
  - 维护应用状态（分类、已安装应用、当前选中项、搜索文本）
  - 封装业务操作：
    - 分类增删改
    - 分类拖动排序
    - 应用归类/移除
    - 自动整理（规则分类）
  - 统一触发 JSON 持久化
- **数据与服务层**
  - `AppScanner`：读取 `/Applications` 和 `~/Applications`
  - `JSONStore`：管理本地 JSON 文件读写

---

## 运行方式

### 1) 开发调试运行

在终端执行：

```bash
cd /Users/heloveyy/Desktop/Cursor/AppOrganizerMVP
swift run
```

或使用 Xcode 打开 `Package.swift` 后运行。

### 2) 编译检查

```bash
cd /Users/heloveyy/Desktop/Cursor/AppOrganizerMVP
swift build
```

### 3) 打包为可运行 `.app`

```bash
cd /Users/heloveyy/Desktop/Cursor/AppOrganizerMVP
./bundle-app.sh
```

打包输出：
- `dist/AppOrganizer.app`

运行方式：

```bash
open "/Users/heloveyy/Desktop/Cursor/AppOrganizerMVP/dist/AppOrganizer.app"
```

---

## 当前功能清单（MVP）

- 分类管理：新建、编辑、删除、删除全部
- 分类排序：通过左侧列表拖动手柄调整顺序
- 应用展示：图标网格（上图标、下名称）
- 应用操作：
  - 已归类区：单击打开，右键移除
  - 未归类区：单击加入分类
- 自动整理：
  - 点击后先确认，再执行
  - 完成后显示统计结果
  - 文案提示“识别可能不准确”
- 即时提示：
  - 关键按钮支持鼠标悬浮即时提示（无系统 tooltip 延迟）

---

## 后续可扩展方向

- 自动整理规则配置化（外置 JSON）
- 分类导入/导出
- 多标签归类（同一 App 可属于多个分类）
- 自定义应用图标缓存与性能优化
- 代码签名与分发流程（面向多设备使用）
