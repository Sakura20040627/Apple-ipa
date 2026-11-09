import SwiftUI
import PhotosUI
import AVFoundation
import HexPickCore

struct CompareView: View {
    @Environment(AppStore.self) private var store
    var initialHeroID: String = ""
    @State private var heroID = ""
    @State private var slots = ["", "", ""]
    @State private var pickerSlot: Int?
    @State private var showHeroPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var busy = false
    @State private var error: String?
    @State private var lines: [OCRLine] = []
    @State private var showReview = false
    @State private var confirmed = true
    private let ocr = OCRService()
    private var canRank: Bool { !heroID.isEmpty && slots.allSatisfy { !$0.isEmpty } && Set(slots).count == 3 && confirmed }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("选对这一次。").font(.largeTitle.bold())
                Text("先选英雄，再填入屏幕上的三个海克斯。").foregroundStyle(Theme.secondary)
                Button { showHeroPicker = true } label: {
                    HStack {
                        if let hero = store.heroes[heroID] { HeroPortrait(id: heroID, name: hero.name, size: 48) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前英雄").font(.caption).foregroundStyle(Theme.secondary)
                            Text(store.heroes[heroID]?.name ?? "请选择英雄").font(.headline)
                        }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(14).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
                BandPicker()
                VStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Button { pickerSlot = index } label: {
                            HStack {
                                AugmentIcon(id: slots[index], rarity: store.augments[slots[index]]?.rarity ?? "")
                                Text(store.augments[slots[index]]?.name ?? "选择第 \(index + 1) 个海克斯")
                                    .foregroundStyle(slots[index].isEmpty ? Theme.secondary : Theme.text)
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }.padding(14).frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("导入截图", systemImage: "photo").frame(minWidth: 44, minHeight: 44) }
                    Button { Task { await openCamera() } } label: { Label("拍摄屏幕", systemImage: "camera").frame(minWidth: 44, minHeight: 44) }
                }.font(.subheadline.weight(.medium)).padding(14).frame(maxWidth: .infinity).glassEffect()
                    .disabled(busy)
                if busy { ProgressView("在本机识别中文名称…") }
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.gold) }
                if !confirmed {
                    Label("截图结果需要逐项确认，当前不生成推荐", systemImage: "checkmark.shield").font(.footnote)
                    Button("确认或修改识别结果") { showReview = true }
                }
                if Set(slots.filter { !$0.isEmpty }).count != slots.filter({ !$0.isEmpty }).count {
                    Text("三个候选不能重复，请修改。").font(.footnote).foregroundStyle(Theme.gold)
                }
                if canRank {
                    Text("本轮推荐").font(.title2.bold())
                    ForEach(Array(store.recommendations(heroID: heroID, ids: slots).enumerated()), id: \.element.id) { index, result in
                        RecommendationCard(result: result, position: index + 1)
                    }
                }
                Text(statisticalNotice).font(.footnote).foregroundStyle(Theme.secondary)
                NavigationLink("了解推荐算法") { AlgorithmView() }.font(.footnote)
            }.padding(20)
        }
        .hexBackground()
        .navigationTitle("三选一").navigationBarTitleDisplayMode(.inline)
        .onAppear { if heroID.isEmpty { heroID = initialHeroID } }
        .sheet(isPresented: Binding(get: { pickerSlot != nil }, set: { if !$0 { pickerSlot = nil } })) {
            NavigationStack {
                AugmentPicker(excluding: Set(slots.enumerated().filter { $0.offset != pickerSlot }.map(\.element))) { id in
                    if let index = pickerSlot { slots[index] = id }; pickerSlot = nil
                }
            }
        }
        .sheet(isPresented: $showHeroPicker) { NavigationStack { HeroSelectionView(selectedID: $heroID) } }
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                if let data { Task { await recognize(data) } }
            }.ignoresSafeArea()
        }
        .sheet(isPresented: $showReview) {
            OCRReviewView(lines: lines, originalSlots: slots) { chosen in
                slots = chosen; confirmed = true; showReview = false
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw DataError.invalid("无法读取截图") }
                    await recognize(data)
                } catch { self.error = error.localizedDescription }
                selectedPhoto = nil
            }
        }
    }
    @MainActor private func recognize(_ data: Data) async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do {
            lines = try await ocr.recognize(data: data, augments: store.augments)
            slots = ["", "", ""]; confirmed = false; showReview = true
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "此设备没有可用相机，可以导入截图。"; return }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        if allowed { showCamera = true } else { error = "相机权限未开启，可在系统设置允许相机，或使用相册导入。" }
    }
}
struct AugmentPicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let excluding: Set<String>
    let onSelect: (String) -> Void
    @State private var search = ""
    @State private var rarity = ""
    private var ids: [String] {
        store.augments.keys.filter { id in
            guard let a = store.augments[id] else { return false }
            return !excluding.contains(id) && (search.isEmpty || a.name.localizedStandardContains(search)) && (rarity.isEmpty || a.rarity == rarity)
        }.sorted { (store.augments[$0]?.name ?? "").localizedStandardCompare(store.augments[$1]?.name ?? "") == .orderedAscending }
    }
    var body: some View {
        List {
            RarityPicker(value: $rarity)
            ForEach(ids, id: \.self) { id in
                if let a = store.augments[id] {
                    Button { onSelect(id) } label: {
                        HStack { AugmentIcon(id: id, rarity: a.rarity); Text(a.name); Spacer(); Text(a.rarityLabel).font(.caption).foregroundStyle(Theme.secondary) }.frame(minHeight: 44)
                    }.tint(Theme.text)
                        .task { await prefetchIcons(after: id, in: ids, store: store) }
                }
            }
            if ids.isEmpty { Text("没有匹配的海克斯，请尝试部分名称。") }
        }.navigationTitle("选择海克斯").searchable(text: $search, prompt: "搜索海克斯名称")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
    }
}
struct OCRReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let lines: [OCRLine]
    let originalSlots: [String]
    let onConfirm: ([String]) -> Void
    @State private var slots = ["", "", ""]
    @State private var activeSlot = 0
    @State private var showManual = false
    private var complete: Bool { slots.allSatisfy { !$0.isEmpty } && Set(slots).count == 3 }
    var body: some View {
        NavigationStack {
            List {
                Section("先点候选位置，再点识别名称进行填入") {
                    ForEach(0..<3) { index in
                        HStack {
                            Button { activeSlot = index } label: {
                                Label(store.augments[slots[index]]?.name ?? "第 \(index + 1) 个：未确认", systemImage: activeSlot == index ? "checkmark.circle.fill" : "circle")
                            }.buttonStyle(.borderless).frame(minWidth: 44, minHeight: 44)
                            Spacer()
                            Button("手动") { activeSlot = index; showManual = true }.buttonStyle(.borderless).frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
                Section {
                    Text("OCR 置信度和名称相似度不是正确率。所有结果都需你核对；不会自动把模糊结果当作已识别成功。")
                        .font(.footnote).foregroundStyle(Theme.secondary)
                }
                if lines.isEmpty { Section { Text("未识别到文本，请手动选择三个海克斯。") } }
                ForEach(lines) { line in
                    Section {
                        Text(line.text).textSelection(.enabled)
                        Text("OCR 置信度 \(Int(line.confidence * 100))%").font(.caption).foregroundStyle(Theme.secondary)
                        if line.matches.isEmpty { Text("未找到可靠匹配").font(.caption).foregroundStyle(Theme.gold) }
                        ForEach(line.matches) { match in
                            Button {
                                slots[activeSlot] = match.id
                                if activeSlot < 2 { activeSlot += 1 }
                            } label: {
                                HStack { Text(store.augments[match.id]?.name ?? match.id); Spacer(); Text("相似度 \(Int(match.similarity * 100))%").font(.caption) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("确认识别结果").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("确认三个候选") { onConfirm(slots) }.disabled(!complete) }
            }
            .sheet(isPresented: $showManual) {
                NavigationStack {
                    AugmentPicker(excluding: Set(slots.enumerated().filter { $0.offset != activeSlot }.map(\.element))) { id in
                        slots[activeSlot] = id; showManual = false
                    }
                }
            }
            .onAppear { slots = originalSlots }
        }
    }
}

struct HeroSelectionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedID: String
    @State private var search = ""
    var body: some View {
        List(store.orderedHeroes.filter { search.isEmpty || (store.heroes[$0]?.name.localizedStandardContains(search) ?? false) }, id: \.self) { id in
            if let hero = store.heroes[id] {
                Button {
                    selectedID = id; dismiss()
                } label: {
                    HStack {
                        HeroPortrait(id: id, name: hero.name, size: 44)
                        Text(hero.name); Spacer()
                        WinRateView(rate: hero.winRate)
                        if id == selectedID { Image(systemName: "checkmark") }
                    }
                }.tint(.primary)
            }
        }.navigationTitle("选择英雄").searchable(text: $search, prompt: "搜索英雄名称")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
    }
}
