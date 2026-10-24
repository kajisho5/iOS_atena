import AtenaCore
import StoreKitTest
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import AtenaPrint

private final class BundleToken {}

/// Captures full screens with fictional sample data when SNAPSHOT_DIR is set.
/// Used to check dark mode, Dynamic Type and split-screen widths, and as the source of the mockups.
@MainActor
@Suite(.serialized) struct ScreenSnapshotTests {
    struct Shot {
        let name: String
        let size: CGSize
        var style: UIUserInterfaceStyle = .light
        var dynamicType: DynamicTypeSize = .large
        var regularWidth: Bool? = nil
        let view: AnyView
    }

    @Test func captureScreens() async throws {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        if let url = Bundle(for: BundleToken.self).url(forResource: "Products", withExtension: "storekit") {
            let session = try SKTestSession(contentsOf: url)
            session.disableDialogs = true
            session.clearTransactions()
        }
        let store = StoreService()
        await store.loadProduct()

        let defaults = try #require(UserDefaults(suiteName: "snapshots-\(UUID().uuidString)"))
        let layoutStore = LayoutStore(defaults: defaults)
        layoutStore.settings.printsSender = true

        let sample = try SampleData.make()
        let empty = try PersistenceController.makeContainer(inMemory: true)

        func wrap(_ view: some View, container: ModelContainer? = nil) -> AnyView {
            AnyView(view.modelContainer(container ?? sample.container).environment(store).environment(layoutStore))
        }

        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let screen = UIScreen.main.bounds.size
        let portrait = CGSize(width: min(screen.width, screen.height), height: max(screen.width, screen.height))
        let landscape = CGSize(width: portrait.height, height: portrait.width)
        let printRequest = PrintRequest(recipients: sample.group.recipients.sorted { $0.sortKey < $1.sortKey }, group: sample.group)

        var shots: [Shot] = []
        if isPad {
            shots += [
                Shot(name: "ipad-landscape-recipients", size: landscape, regularWidth: true,
                     view: wrap(RootView(initialScope: .group(sample.group), initialRecipient: sample.featured))),
                Shot(name: "ipad-landscape-preview", size: landscape, regularWidth: true, view: wrap(PrintPreviewView(request: printRequest))),
                Shot(name: "ipad-landscape-layout", size: landscape, regularWidth: true, view: wrap(RootView(initialTab: .layout))),
                Shot(name: "ipad-portrait-recipients", size: portrait, regularWidth: true,
                     view: wrap(RootView(initialScope: .group(sample.group), initialRecipient: sample.featured))),
                Shot(name: "ipad-portrait-preview", size: portrait, regularWidth: true, view: wrap(PrintPreviewView(request: printRequest))),
                Shot(name: "ipad-landscape-preview-dark", size: landscape, style: .dark, regularWidth: true, view: wrap(PrintPreviewView(request: printRequest))),
                // Split View / windowed widths (approximate): one third, half, two thirds.
                Shot(name: "ipad-split-third", size: CGSize(width: 375, height: landscape.height), regularWidth: false,
                     view: wrap(RootView(initialScope: .group(sample.group)))),
                Shot(name: "ipad-split-half", size: CGSize(width: landscape.width / 2 - 5, height: landscape.height), regularWidth: false,
                     view: wrap(PrintPreviewView(request: printRequest))),
                Shot(name: "ipad-split-twothirds", size: CGSize(width: landscape.width * 2 / 3, height: landscape.height), regularWidth: true,
                     view: wrap(RootView(initialScope: .group(sample.group), initialRecipient: sample.featured))),
            ]
        } else {
            let csv = CSVImportSource(data: CSVWriter.data(from: SampleData.csvRows), fileName: "住所録.csv")
            shots += [
                Shot(name: "iphone-groups", size: portrait, view: wrap(RootView())),
                Shot(name: "iphone-list", size: portrait, view: wrap(RootView(initialScope: .group(sample.group)))),
                Shot(name: "iphone-editor", size: portrait, view: wrap(RecipientEditorView(mode: .edit(sample.featured)))),
                Shot(name: "iphone-preview", size: portrait, view: wrap(PrintPreviewView(request: printRequest))),
                Shot(name: "iphone-layout", size: portrait, view: wrap(RootView(initialTab: .layout))),
                Shot(name: "iphone-settings", size: portrait, view: wrap(RootView(initialTab: .settings))),
                Shot(name: "iphone-paywall", size: portrait, view: wrap(PaywallView(reason: .settings))),
                Shot(name: "iphone-csv", size: portrait, view: wrap(CSVImportView(source: csv, initialGroup: sample.group))),
                Shot(name: "iphone-empty", size: portrait, view: wrap(RootView(initialScope: .all), container: empty)),
                Shot(name: "iphone-list-dark", size: portrait, style: .dark, view: wrap(RootView(initialScope: .group(sample.group)))),
                Shot(name: "iphone-preview-dark", size: portrait, style: .dark, view: wrap(PrintPreviewView(request: printRequest))),
                Shot(name: "iphone-paywall-dark", size: portrait, style: .dark, view: wrap(PaywallView(reason: .settings))),
                Shot(name: "iphone-list-ax5", size: portrait, dynamicType: .accessibility5, view: wrap(RootView(initialScope: .group(sample.group)))),
                Shot(name: "iphone-preview-ax5", size: portrait, dynamicType: .accessibility5, view: wrap(PrintPreviewView(request: printRequest))),
                Shot(name: "iphone-paywall-ax5", size: portrait, dynamicType: .accessibility5, view: wrap(PaywallView(reason: .settings))),
            ]
        }

        for shot in shots {
            let image = try await render(shot)
            let data = try #require(image.pngData())
            try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("screen-\(shot.name).png"))
        }
    }

    private func render(_ shot: Shot) async throws -> UIImage {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: shot.size)
        window.overrideUserInterfaceStyle = shot.style
        let host = UIHostingController(rootView: AnyView(shot.view.environment(\.dynamicTypeSize, shot.dynamicType)))
        if let regular = shot.regularWidth {
            host.traitOverrides.horizontalSizeClass = regular ? .regular : .compact
        }
        window.rootViewController = host
        window.isHidden = false
        // Let SwiftUI resolve queries, layout and the StoreKit product.
        for _ in 0..<6 {
            try await Task.sleep(for: .milliseconds(250))
            window.layoutIfNeeded()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        window.isHidden = true
        window.rootViewController = nil
        return image
    }
}

/// Fictional sample data (names and addresses do not refer to real people).
@MainActor
enum SampleData {
    struct Result {
        let container: ModelContainer
        let group: RecipientGroup
        let featured: Recipient
    }

    static let csvRows: [[String]] = [
        ["名前", "〒", "住所", "建物名", "連名", "備考"],
        ["青木 健", "150-0001", "東京都渋谷区見本町2-3-1", "", "", ""],
        ["伊藤 美咲", "220-0012", "神奈川県横浜市西区見本台4-5-6", "見本タワー1205", "", ""],
        ["株式会社見本商事", "530-0001", "大阪府大阪市北区見本通1-1-1", "見本ビル8階", "", ""],
        ["佐藤 一郎", "460-0008", "愛知県名古屋市中区見本町3-2", "", "", "喪中（2026）"],
        ["山田 太郎", "104-0061", "東京都中央区見本町1-13-3", "サンプルハイツ203", "花子", ""],
    ]

    static func make() throws -> Result {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let nenga = RecipientGroup(name: "年賀状2026", sortOrder: 0)
        let work = RecipientGroup(name: "仕事関係", sortOrder: 1)
        let family = RecipientGroup(name: "親戚", sortOrder: 2)
        [nenga, work, family].forEach(context.insert)

        let drafts: [(RecipientDraft, [RecipientGroup], Date?)] = [
            (RecipientDraft(name: "青木 健", nameKana: "あおき けん", postalCode: "1500001", address1: "東京都渋谷区見本町2-3-1"), [nenga], date(2026, 12, 1)),
            (RecipientDraft(name: "伊藤 美咲", nameKana: "いとう みさき", postalCode: "2200012", address1: "神奈川県横浜市西区見本台4-5-6", address2: "見本タワー1205"), [nenga], nil),
            (RecipientDraft(name: "株式会社見本商事", nameKana: "かぶしきがいしゃみほんしょうじ", honorific: "御中", postalCode: "5300001",
                            address1: "大阪府大阪市北区見本通1-1-1", address2: "見本ビル8階"), [nenga, work], nil),
            (RecipientDraft(name: "佐藤 一郎", nameKana: "さとう いちろう", honorific: "先生", postalCode: "4600008", address1: "愛知県名古屋市中区見本町3-2", memo: "喪中（2026）"), [nenga], nil),
            (RecipientDraft(name: "山田 太郎", nameKana: "やまだ たろう", jointNames: ["花子"], postalCode: "1040061",
                            address1: "東京都中央区見本町1-13-3", address2: "サンプルハイツ203"), [nenga, family], date(2026, 12, 1)),
            (RecipientDraft(name: "鈴木 次郎", nameKana: "すずき じろう", postalCode: "9800811", address1: "宮城県仙台市青葉区見本町5-8-2"), [work], nil),
        ]
        var featured: Recipient?
        for (draft, groups, printedAt) in drafts {
            let recipient = Recipient(draft: draft)
            context.insert(recipient)
            recipient.groups = groups
            if let printedAt {
                context.insert(PrintRecord(recipient: recipient, group: nenga, paperKind: PaperKind.hagaki.rawValue, printedAt: printedAt))
            }
            if draft.name == "山田 太郎" { featured = recipient }
        }
        let sender = SenderProfile(label: "自宅", sortOrder: 0)
        sender.name = "田中 一郎"
        sender.postalCode = "1230045"
        sender.address1 = "東京都見本区見本町2-5"
        context.insert(sender)
        try context.save()
        return Result(container: container, group: nenga, featured: try #require(featured))
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: 10)) ?? Date()
    }
}
