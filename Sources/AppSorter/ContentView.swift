import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var organizer: OrganizerViewModel
    @State private var newCategoryName = ""
    @State private var showingAddCategory = false
    @State private var editingCategoryId: UUID?
    @State private var editingCategoryName = ""
    @State private var draggedCategoryId: UUID?
    @State private var autoOrganizeMessage = ""
    @State private var showingAutoOrganizeResult = false
    @State private var showingAutoOrganizeConfirm = false
    @State private var showingDeleteAllConfirm = false

    var body: some View {
        NavigationSplitView {
            categorySidebar
        } detail: {
            detailPane
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    organizer.refreshInstalledApps()
                } label: {
                    Label("刷新应用列表", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAutoOrganizeConfirm = true
                } label: {
                    Label("一键整理", systemImage: "wand.and.stars")
                }
                .immediateTooltip("自动整理")
            }
        }
        .searchable(text: $organizer.searchText, placement: .toolbar, prompt: "搜索")
        .alert("执行自动整理？", isPresented: $showingAutoOrganizeConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定整理") {
                let result = organizer.autoOrganizeApps()
                autoOrganizeMessage = """
                已整理 \(result.organizedApps) 个应用，新增 \(result.newCategories) 个分类。

                提示：自动识别分类可能不准确，请注意检查。
                """
                showingAutoOrganizeResult = true
            }
        } message: {
            Text("将根据应用名称/BundleId 自动识别分类并归类；识别结果可能不准确。")
        }
        .alert("自动整理完成", isPresented: $showingAutoOrganizeResult) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(autoOrganizeMessage)
        }
    }

    private var categorySidebar: some View {
        List {
            Section("分类") {
                ForEach(organizer.sortedCategories) { cat in
                    Button {
                        organizer.selectedCategoryId = cat.id
                    } label: {
                        HStack(spacing: 10) {
                            Label(cat.name, systemImage: "folder")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())

                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                                .immediateTooltip("拖动排序")
                                .onDrag {
                                    draggedCategoryId = cat.id
                                    return NSItemProvider(object: cat.id.uuidString as NSString)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        organizer.selectedCategoryId == cat.id
                            ? Color.accentColor.opacity(0.16)
                            : Color.clear
                    )
                        .onDrop(of: [UTType.text], delegate: CategoryDropDelegate(
                            targetCategoryId: cat.id,
                            draggedCategoryId: $draggedCategoryId,
                            organizer: organizer
                        ))
                        .contextMenu {
                            Button("编辑分类") {
                                editingCategoryId = cat.id
                                editingCategoryName = cat.name
                            }
                            Button("删除分类", role: .destructive) {
                                organizer.deleteCategory(id: cat.id)
                            }
                        }
                }
            }
        }
        .navigationTitle("AppSorter")
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAddCategory = true
                } label: {
                    Label("新建分类", systemImage: "folder.badge.plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showingDeleteAllConfirm = true
                } label: {
                    Label("删除全部分类", systemImage: "trash")
                }
                .disabled(organizer.sortedCategories.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            addCategorySheet
        }
        .sheet(isPresented: editingSheetBinding) {
            editCategorySheet
        }
        .alert("删除全部分类？", isPresented: $showingDeleteAllConfirm) {
            Button("取消", role: .cancel) {}
            Button("全部删除", role: .destructive) {
                organizer.deleteAllCategories()
            }
        } message: {
            Text("会删除所有分类及其归类关系，无法恢复。")
        }
    }

    private var addCategorySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建分类")
                .font(.headline)
            TextField("名称", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") {
                    newCategoryName = ""
                    showingAddCategory = false
                }
                .keyboardShortcut(.cancelAction)
                Button("添加") {
                    let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        organizer.addCategory(name: name)
                    }
                    newCategoryName = ""
                    showingAddCategory = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }

    private var editingSheetBinding: Binding<Bool> {
        Binding(
            get: { editingCategoryId != nil },
            set: { isPresented in
                if !isPresented {
                    editingCategoryId = nil
                    editingCategoryName = ""
                }
            }
        )
    }

    private var editCategorySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑分类")
                .font(.headline)
            TextField("名称", text: $editingCategoryName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") {
                    editingCategoryId = nil
                    editingCategoryName = ""
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") {
                    let name = editingCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let id = editingCategoryId, !name.isEmpty {
                        organizer.renameCategory(id: id, to: name)
                    }
                    editingCategoryId = nil
                    editingCategoryName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editingCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = organizer.selectedCategoryId {
            CategoryDetailView(categoryId: id)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("选择分类")
                    .font(.title2)
                Text("在左侧选择或新建一个分类")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CategoryDetailView: View {
    @EnvironmentObject private var organizer: OrganizerViewModel
    let categoryId: UUID

    private var categoryTitle: String {
        organizer.categoryBinding(for: categoryId)?.name ?? "分类"
    }

    private var assignedApps: [InstalledApp] {
        organizer.apps(in: categoryId)
    }

    private var unassignedApps: [InstalledApp] {
        organizer.addableApps
    }

    var body: some View {
        HSplitView {
            appGridSection(
                title: "此分类中的应用",
                subtitle: "单击图标打开 · 右键可移除",
                apps: assignedApps,
                emptyHint: "暂无应用，可从右侧「未归类」中加入",
                badge: .none,
                onSelect: { organizer.open($0) }
            ) { app in
                Button("打开") { organizer.open(app) }
                Divider()
                Button("从分类移除", role: .destructive) {
                    organizer.removeApp(bundleId: app.bundleId, from: categoryId)
                }
            }
            .frame(minWidth: 360)

            appGridSection(
                title: "未归类",
                subtitle: "单击加入当前分类",
                apps: unassignedApps,
                emptyHint: "所有应用都已归类",
                badge: .add,
                onSelect: { organizer.addApp(bundleId: $0.bundleId, to: categoryId) }
            ) { app in
                Button("加入「\(categoryTitle)」") {
                    organizer.addApp(bundleId: app.bundleId, to: categoryId)
                }
            }
            .frame(minWidth: 360)
        }
        .navigationTitle(categoryTitle)
    }

    private func appGridSection<MenuContent: View>(
        title: LocalizedStringKey,
        subtitle: String,
        apps: [InstalledApp],
        emptyHint: String,
        badge: AppGridCell.Badge,
        onSelect: @escaping (InstalledApp) -> Void,
        @ViewBuilder contextMenu: @escaping (InstalledApp) -> MenuContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if apps.isEmpty {
                Text(emptyHint)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 118), spacing: 14),
                        ],
                        spacing: 18
                    ) {
                        ForEach(apps) { app in
                            AppGridCell(app: app, badge: badge) {
                                onSelect(app)
                            }
                            .contextMenu {
                                contextMenu(app)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct AppGridCell: View {
    enum Badge {
        case none
        case add
    }

    let app: InstalledApp
    var badge: Badge = .none
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

                    if badge == .add {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 6, y: -6)
                    }
                }

                Text(app.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 32, alignment: .top)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovering ? 0.12 : 0), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(app.name)
        .onHover { isHovering = $0 }
    }
}

private struct CategoryDropDelegate: DropDelegate {
    let targetCategoryId: UUID
    @Binding var draggedCategoryId: UUID?
    let organizer: OrganizerViewModel

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedCategoryId else { return }
        organizer.moveCategory(draggedId: dragged, to: targetCategoryId)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCategoryId = nil
        return true
    }
}

private struct ImmediateTooltipModifier: ViewModifier {
    let text: String
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
            }
            .popover(isPresented: $hovering, arrowEdge: .bottom) {
                Text(text)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
    }
}

private extension View {
    func immediateTooltip(_ text: String) -> some View {
        modifier(ImmediateTooltipModifier(text: text))
    }
}
