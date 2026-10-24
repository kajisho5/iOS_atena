import Foundation

public enum WritingMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case vertical
    case horizontal

    public var id: String { rawValue }
}

/// What is printed for the recipient.
public struct AddressContent: Equatable, Sendable {
    public var name: String
    public var jointNames: [String]
    public var honorific: String
    public var postalCode: String
    public var address1: String
    public var address2: String

    public init(name: String, jointNames: [String] = [], honorific: String = Honorific.defaultValue,
                postalCode: String = "", address1: String = "", address2: String = "") {
        self.name = name
        self.jointNames = jointNames
        self.honorific = honorific
        self.postalCode = postalCode
        self.address1 = address1
        self.address2 = address2
    }
}

/// What is printed for the sender (no honorific).
public struct SenderContent: Equatable, Sendable {
    public var name: String
    public var jointNames: [String]
    public var postalCode: String
    public var address1: String
    public var address2: String

    public init(name: String, jointNames: [String] = [], postalCode: String = "", address1: String = "", address2: String = "") {
        self.name = name
        self.jointNames = jointNames
        self.postalCode = postalCode
        self.address1 = address1
        self.address2 = address2
    }
}

public struct LayoutOptions: Equatable, Sendable {
    public var paper: PaperKind
    public var writingMode: WritingMode
    public var convertDigitsToKanji: Bool
    public var sender: SenderContent?

    public init(paper: PaperKind = .hagaki, writingMode: WritingMode = .vertical, convertDigitsToKanji: Bool = true, sender: SenderContent? = nil) {
        self.paper = paper
        self.writingMode = writingMode
        self.convertDigitsToKanji = convertDigitsToKanji
        self.sender = sender
    }
}

public enum TextRole: String, CaseIterable, Sendable {
    case recipientPostalCode
    case recipientAddress
    case recipientName
    case senderPostalCode
    case senderAddress
    case senderName
}

/// Measures text in em units (advance length at font size 1). Implemented with Core Text in the
/// app and with a fixed-width approximation in tests.
public protocol TextMeasuring {
    func advance(of text: String, vertical: Bool) -> Double
}

/// A positioned piece of text. Sizes are in millimeters.
public struct TextRun: Equatable, Sendable {
    public enum Alignment: Sendable {
        case leading
        case center
    }

    public var text: String
    public var role: TextRole
    /// Em size in millimeters.
    public var fontSize: Double
    public var vertical: Bool
    /// Extra space between characters in millimeters.
    public var tracking: Double
    /// Vertical: column box (x = left of the column, width = font size). Horizontal: line box.
    public var frame: MMRect
    public var alignment: Alignment
}

public struct LayoutResult: Equatable, Sendable {
    public var paperSize: MMSize
    public var runs: [TextRun]
    /// Roles whose text could not fit even at the minimum size.
    public var overflowingRoles: Set<TextRole>
    /// Postal-code boxes for on-screen guides (never printed).
    public var postalFrames: [MMRect]

    public var hasOverflow: Bool { !overflowingRoles.isEmpty }
}

/// Lays out the address side of a sheet. Pure geometry: no fonts, no drawing.
public struct AddressLayoutEngine {
    let measurer: any TextMeasuring

    public init(measurer: any TextMeasuring) {
        self.measurer = measurer
    }

    /// Tracking applied to names, as a fraction of the font size.
    static let nameTracking = 0.15
    static let columnPitch = 1.4

    public func layout(_ content: AddressContent, options: LayoutOptions) -> LayoutResult {
        let size = options.paper.size
        var result = LayoutResult(paperSize: size, runs: [], overflowingRoles: [], postalFrames: PostalFrame.boxes(paperWidth: size.width))
        placePostalDigits(content.postalCode, into: &result)
        switch options.writingMode {
        case .vertical:
            layoutVertical(content, options: options, into: &result)
        case .horizontal:
            layoutHorizontal(content, options: options, into: &result)
        }
        return result
    }

    // MARK: - Postal code

    private func placePostalDigits(_ postalCode: String, into result: inout LayoutResult) {
        guard let digits = PostalCode.normalize(postalCode) else { return }
        for (box, digit) in zip(result.postalFrames, digits) {
            result.runs.append(TextRun(text: String(digit), role: .recipientPostalCode, fontSize: PostalFrame.boxHeight * 0.78,
                                       vertical: false, tracking: 0, frame: box, alignment: .center))
        }
    }

    // MARK: - Vertical

    private func layoutVertical(_ content: AddressContent, options: LayoutOptions, into result: inout LayoutResult) {
        let paper = result.paperSize
        let k = paper.width / 100
        let kv = paper.height / 148
        let hasSender = options.sender != nil

        // Recipient address: columns from the right edge, below the postal frames.
        let addressTop = PostalFrame.bottom + 7 * kv
        let addressBottom = paper.height - 10 * kv
        let addressRight = paper.width - PostalFrame.rightMargin
        let addressLines = [content.address1, content.address2]
            .map { VerticalTextNormalizer.normalize($0, convertDigitsToKanji: options.convertDigitsToKanji) }
        let address = fitColumns(lines: addressLines, top: addressTop, bottom: addressBottom, indentEm: 2,
                                 maxSize: 6.0 * k, minSize: 3.4 * k, maxColumns: 3)
        if address.overflow { result.overflowingRoles.insert(.recipientAddress) }
        var columnX = addressRight - address.size
        for column in address.columns {
            result.runs.append(TextRun(text: column.text, role: .recipientAddress, fontSize: address.size, vertical: true, tracking: 0,
                                       frame: MMRect(x: columnX, y: column.top, width: address.size, height: column.length),
                                       alignment: .leading))
            columnX -= address.size * Self.columnPitch
        }
        let addressLeft = columnX + address.size * Self.columnPitch

        // Sender block (bottom-left).
        var senderRight = 4 * k
        if let sender = options.sender {
            senderRight = layoutVerticalSender(sender, options: options, k: k, kv: kv, into: &result)
        }

        // Recipient name: centered between the sender block and the address columns.
        let nameTop = PostalFrame.bottom + 12 * kv
        let nameBottom = paper.height - (hasSender ? 16 : 12) * kv
        let nameAreaLeft = senderRight + 3 * k
        let nameAreaRight = addressLeft - 3 * k
        let name = nameColumns(name: content.name, jointNames: content.jointNames, honorific: content.honorific,
                               top: nameTop, bottom: nameBottom, areaWidth: nameAreaRight - nameAreaLeft,
                               maxSize: 11 * k, minSize: 6 * k)
        if name.overflow { result.overflowingRoles.insert(.recipientName) }
        let pitch = name.size * (1 + Self.nameTracking + 0.15)
        let blockWidth = name.size + pitch * Double(name.columns.count - 1)
        let center = min(max(paper.width / 2, nameAreaLeft + blockWidth / 2), nameAreaRight - blockWidth / 2)
        var nameX = center + blockWidth / 2 - name.size
        for column in name.columns {
            result.runs.append(TextRun(text: column.text, role: .recipientName, fontSize: name.size, vertical: true,
                                       tracking: name.size * Self.nameTracking,
                                       frame: MMRect(x: nameX, y: column.top, width: name.size, height: column.length),
                                       alignment: .leading))
            nameX -= pitch
        }
    }

    /// Returns the right edge of the sender block.
    private func layoutVerticalSender(_ sender: SenderContent, options: LayoutOptions, k: Double, kv: Double, into result: inout LayoutResult) -> Double {
        let paper = result.paperSize
        let left = 6 * k
        let top = paper.height * 0.5
        let bottom = paper.height - 16 * kv
        let maxRight = paper.width * 0.34

        let lines = [sender.address1, sender.address2]
            .map { VerticalTextNormalizer.normalize($0, convertDigitsToKanji: options.convertDigitsToKanji) }
        let address = fitColumns(lines: lines, top: top, bottom: bottom, indentEm: 1, maxSize: 3.6 * k, minSize: 2.4 * k, maxColumns: 3)
        let nameText = [sender.name] + sender.jointNames
        let names = nameText.filter { !$0.isEmpty }.map { normalizeName($0) }
        var nameFit = fitUniform(texts: names, length: bottom - (top + 6 * kv), maxSize: 4.8 * k, minSize: 3.0 * k, tracking: Self.nameTracking)
        let addressWidths = Double(address.columns.count) * address.size * Self.columnPitch
        // Many sender names (joint names) must still fit between the left margin and `maxRight`:
        // shrink the names to the width that is left, and report an overflow below the minimum size.
        if !names.isEmpty {
            let widthCap = max(0.5 * k, (maxRight - left - addressWidths) / (Double(names.count) * 1.35))
            if nameFit.size > widthCap {
                if widthCap < 3.0 * k { nameFit.overflow = true }
                nameFit.size = widthCap
            }
        }

        if address.overflow { result.overflowingRoles.insert(.senderAddress) }
        if nameFit.overflow { result.overflowingRoles.insert(.senderName) }

        // Columns right-to-left: address, then names; the whole block is anchored at `left`.
        let nameWidths = Double(names.count) * nameFit.size * 1.35
        var x = min(left + addressWidths + nameWidths, maxRight) - address.size
        for column in address.columns {
            result.runs.append(TextRun(text: column.text, role: .senderAddress, fontSize: address.size, vertical: true, tracking: 0,
                                       frame: MMRect(x: x, y: column.top, width: address.size, height: column.length), alignment: .leading))
            x -= address.size * Self.columnPitch
        }
        x += address.size * Self.columnPitch - nameFit.size * 1.35
        for name in names {
            let length = columnLength(name, size: nameFit.size, tracking: Self.nameTracking)
            result.runs.append(TextRun(text: name, role: .senderName, fontSize: nameFit.size, vertical: true,
                                       tracking: nameFit.size * Self.nameTracking,
                                       frame: MMRect(x: x, y: bottom - length, width: nameFit.size, height: length), alignment: .leading))
            x -= nameFit.size * 1.35
        }

        if let digits = PostalCode.normalize(sender.postalCode) {
            let size = 3.2 * k
            result.runs.append(TextRun(text: "〒" + PostalCode.formatted(digits), role: .senderPostalCode, fontSize: size, vertical: false,
                                       tracking: size * 0.15,
                                       frame: MMRect(x: left, y: paper.height - 11 * kv, width: maxRight - left + 6 * k, height: size * 1.2),
                                       alignment: .leading))
        }
        return min(left + addressWidths + nameWidths, maxRight)
    }

    // MARK: - Horizontal

    private func layoutHorizontal(_ content: AddressContent, options: LayoutOptions, into result: inout LayoutResult) {
        let paper = result.paperSize
        let k = paper.width / 100
        let kv = paper.height / 148
        let left = 12 * k
        let right = paper.width - 8 * k
        let width = right - left

        // Address lines below the postal frames.
        let addressLines = [content.address1, content.address2].map(TextNormalization.trimmed).filter { !$0.isEmpty }
        let address = fitLines(lines: addressLines, width: width, indentEm: 1, maxSize: 5.0 * k, minSize: 3.2 * k, maxLines: 3)
        if address.overflow { result.overflowingRoles.insert(.recipientAddress) }
        var y = PostalFrame.bottom + 10 * kv
        for line in address.lines {
            result.runs.append(TextRun(text: line.text, role: .recipientAddress, fontSize: address.size, vertical: false, tracking: 0,
                                       frame: MMRect(x: left + line.indent, y: y, width: line.length, height: address.size * 1.2), alignment: .leading))
            y += address.size * 1.5
        }

        // Name block, centered.
        let mainText = normalizeName(content.name) + " " + content.honorific
        let jointTexts = content.jointNames.filter { !$0.isEmpty }.map { $0 + " " + content.honorific }
        let familyOffsetUnits = familyPrefixUnits(content.name, vertical: false)
        let maxUnits = max(advance(mainText, tracking: Self.nameTracking, vertical: false),
                           familyOffsetUnits + (jointTexts.map { advance($0, tracking: Self.nameTracking, vertical: false) }.max() ?? 0))
        let nameMax = 9 * k
        let nameMin = 5 * k
        var nameSize = min(nameMax, width / max(maxUnits, 1))
        if nameSize < nameMin {
            nameSize = nameMin
            result.overflowingRoles.insert(.recipientName)
        }
        let lineHeight = nameSize * 1.45
        let blockHeight = lineHeight * Double(1 + jointTexts.count)
        let blockWidth = maxUnits * nameSize
        let nameLeft = left + max(0, (width - blockWidth) / 2)
        var nameY = max(y + 6 * kv, paper.height * 0.46 - blockHeight / 2)
        result.runs.append(TextRun(text: mainText, role: .recipientName, fontSize: nameSize, vertical: false,
                                   tracking: nameSize * Self.nameTracking,
                                   frame: MMRect(x: nameLeft, y: nameY, width: advance(mainText, tracking: Self.nameTracking, vertical: false) * nameSize, height: nameSize * 1.2),
                                   alignment: .leading))
        for joint in jointTexts {
            nameY += lineHeight
            result.runs.append(TextRun(text: joint, role: .recipientName, fontSize: nameSize, vertical: false,
                                       tracking: nameSize * Self.nameTracking,
                                       frame: MMRect(x: nameLeft + familyOffsetUnits * nameSize, y: nameY,
                                                     width: advance(joint, tracking: Self.nameTracking, vertical: false) * nameSize, height: nameSize * 1.2),
                                       alignment: .leading))
        }

        // Sender lines at the bottom-left.
        if let sender = options.sender {
            var lines: [(String, TextRole)] = []
            if let digits = PostalCode.normalize(sender.postalCode) {
                lines.append(("〒" + PostalCode.formatted(digits), .senderPostalCode))
            }
            for line in [sender.address1, sender.address2] where !TextNormalization.trimmed(line).isEmpty {
                lines.append((TextNormalization.trimmed(line), .senderAddress))
            }
            for name in ([sender.name] + sender.jointNames) where !name.isEmpty {
                lines.append((normalizeName(name), .senderName))
            }
            let senderWidth = paper.width * 0.62
            let widest = lines.map { advance($0.0, tracking: 0, vertical: false) }.max() ?? 1
            var senderSize = min(3.4 * k, senderWidth / max(widest, 1))
            if senderSize < 2.4 * k {
                senderSize = 2.4 * k
                result.overflowingRoles.insert(.senderAddress)
            }
            var senderY = paper.height - 8 * kv - Double(lines.count) * senderSize * 1.4
            for (text, role) in lines {
                result.runs.append(TextRun(text: text, role: role, fontSize: senderSize, vertical: false, tracking: 0,
                                           frame: MMRect(x: left, y: senderY, width: advance(text, tracking: 0, vertical: false) * senderSize, height: senderSize * 1.2),
                                           alignment: .leading))
                senderY += senderSize * 1.4
            }
        }
    }

    // MARK: - Fitting helpers

    struct Column {
        var text: String
        var top: Double
        var length: Double
    }

    struct ColumnFit {
        var size: Double
        var columns: [Column]
        var overflow: Bool
    }

    /// Fits address lines into vertical columns. The first line may wrap into extra columns.
    /// Every column shares one font size.
    func fitColumns(lines: [String], top: Double, bottom: Double, indentEm: Double, maxSize: Double, minSize: Double, maxColumns: Int,
                    vertical: Bool = true) -> ColumnFit {
        let available = bottom - top
        let nonEmpty = lines.map(TextNormalization.trimmed)
        let first = nonEmpty.first ?? ""
        let rest = nonEmpty.dropFirst().filter { !$0.isEmpty }

        func build(size: Double, firstLineColumns: Int) -> (pieces: [(String, Double)], fits: Bool) {
            var pieces: [(String, Double)] = []
            let maxUnits = available / size
            var remaining = first
            while !remaining.isEmpty {
                let indent = pieces.isEmpty ? 0.0 : indentEm
                let room = maxUnits - indent
                if advance(remaining, tracking: 0, vertical: vertical) <= room || pieces.count + 1 >= firstLineColumns {
                    pieces.append((remaining, indent))
                    remaining = ""
                } else {
                    let (head, tail) = split(remaining, maxUnits: room, vertical: vertical)
                    pieces.append((head, indent))
                    remaining = tail
                }
            }
            for line in rest {
                pieces.append((line, indentEm))
            }
            let fits = pieces.allSatisfy { advance($0.0, tracking: 0, vertical: vertical) + $0.1 <= maxUnits + 0.0001 }
            return (pieces, fits)
        }

        /// Largest size (down to the minimum) at which the text fits with the given column budget.
        func fit(firstLineColumns: Int) -> (size: Double, pieces: [(String, Double)], fits: Bool) {
            var size = maxSize
            var attempt = build(size: size, firstLineColumns: firstLineColumns)
            while !attempt.fits, size > minSize {
                size = max(minSize, size - 0.1)
                attempt = build(size: size, firstLineColumns: firstLineColumns)
            }
            return (size, attempt.pieces, attempt.fits)
        }

        // Prefer fewer columns while the text stays reasonably large; wrap only when needed.
        let budget = max(1, maxColumns - rest.count)
        let attempts = (1...budget).map { fit(firstLineColumns: $0) }
        let chosen = attempts.first { $0.fits && $0.size >= maxSize * 0.7 }
            ?? attempts.filter(\.fits).max { $0.size < $1.size }
            ?? attempts[attempts.count - 1]
        let size = chosen.size
        let columns = chosen.pieces.map { piece in
            Column(text: piece.0, top: top + piece.1 * size, length: advance(piece.0, tracking: 0, vertical: vertical) * size)
        }
        return ColumnFit(size: size, columns: columns, overflow: !chosen.fits)
    }

    /// Name columns: the main name ends with the honorific; joint names are aligned so that every
    /// honorific sits at the same height.
    func nameColumns(name: String, jointNames: [String], honorific: String, top: Double, bottom: Double, areaWidth: Double,
                     maxSize: Double, minSize: Double) -> ColumnFit {
        let mainText = normalizeName(name) + " " + honorific
        let joints = jointNames.filter { !$0.isEmpty }.map { $0 + " " + honorific }
        let columnCount = Double(1 + joints.count)
        // Size for the longest column: joint columns end at the same height as the main one, so a long
        // joint name would otherwise run off the top of the sheet.
        let longestUnits = ([mainText] + joints).map { advance($0, tracking: Self.nameTracking) }.max() ?? 0
        let sizeForHeight = (bottom - top) / max(longestUnits, 1)
        let pitchFactor = 1 + Self.nameTracking + 0.15
        let sizeForWidth = areaWidth / (1 + pitchFactor * (columnCount - 1))
        var size = min(maxSize, sizeForHeight, sizeForWidth)
        var overflow = false
        if size < minSize {
            size = minSize
            overflow = true
        }
        // Center the longest column vertically; every column ends (with its honorific) at the same height.
        let mainLength = columnLength(mainText, size: size, tracking: Self.nameTracking)
        let jointLengths = joints.map { columnLength($0, size: size, tracking: Self.nameTracking) }
        let longest = ([mainLength] + jointLengths).max() ?? mainLength
        let baseline = top + max(0, (bottom - top - longest) / 2) + longest
        var columns = [Column(text: mainText, top: baseline - mainLength, length: mainLength)]
        for (joint, length) in zip(joints, jointLengths) {
            columns.append(Column(text: joint, top: baseline - length, length: length))
        }
        return ColumnFit(size: size, columns: columns, overflow: overflow)
    }

    struct UniformFit {
        var size: Double
        var overflow: Bool
    }

    func fitUniform(texts: [String], length: Double, maxSize: Double, minSize: Double, tracking: Double) -> UniformFit {
        let units = texts.map { advance($0, tracking: tracking) }.max() ?? 0
        guard units > 0 else { return UniformFit(size: maxSize, overflow: false) }
        let size = min(maxSize, length / units)
        return size < minSize ? UniformFit(size: minSize, overflow: true) : UniformFit(size: size, overflow: false)
    }

    struct Line {
        var text: String
        var indent: Double
        var length: Double
    }

    struct LineFit {
        var size: Double
        var lines: [Line]
        var overflow: Bool
    }

    func fitLines(lines: [String], width: Double, indentEm: Double, maxSize: Double, minSize: Double, maxLines: Int) -> LineFit {
        let columnFit = fitColumns(lines: lines, top: 0, bottom: width, indentEm: indentEm, maxSize: maxSize, minSize: minSize,
                                   maxColumns: maxLines, vertical: false)
        let result = columnFit.columns.map { Line(text: $0.text, indent: $0.top, length: $0.length) }
        return LineFit(size: columnFit.size, lines: result, overflow: columnFit.overflow)
    }

    // MARK: - Measuring

    /// Advance in em units including tracking between characters.
    func advance(_ text: String, tracking: Double, vertical: Bool = true) -> Double {
        guard !text.isEmpty else { return 0 }
        return measurer.advance(of: text, vertical: vertical) + tracking * Double(max(text.count - 1, 0))
    }

    func columnLength(_ text: String, size: Double, tracking: Double) -> Double {
        advance(text, tracking: tracking) * size
    }

    /// "山田　太郎" → "山田 太郎". A single ASCII space, set as a half-em gap, separates family and given names.
    func normalizeName(_ name: String) -> String {
        TextNormalization.trimmed(name)
            .split(whereSeparator: { $0 == " " || $0 == "\u{3000}" })
            .joined(separator: " ")
    }

    /// Width of "family name + space" in em units, used to align joint names under the given name.
    func familyPrefixUnits(_ name: String, vertical: Bool = true) -> Double {
        let parts = TextNormalization.trimmed(name).split(whereSeparator: { $0 == " " || $0 == "\u{3000}" })
        guard parts.count > 1, let family = parts.first else { return 0 }
        return advance(String(family) + " ", tracking: Self.nameTracking, vertical: vertical) + Self.nameTracking
    }

    /// Splits `text` so that the head fits in `maxUnits`, preferring a break after an
    /// administrative suffix (都道府県市区町村郡) or before a numeral.
    func split(_ text: String, maxUnits: Double, vertical: Bool = true) -> (String, String) {
        let characters = Array(text)
        var fitCount = 0
        for count in 1...characters.count where advance(String(characters[0..<count]), tracking: 0, vertical: vertical) <= maxUnits {
            fitCount = count
        }
        fitCount = max(fitCount, 1)
        guard fitCount < characters.count else { return (text, "") }
        let preferredAfter: Set<Character> = ["都", "道", "府", "県", "市", "区", "町", "村", "郡", "目"]
        let lowerBound = max(1, Int(Double(fitCount) * 0.5))
        var breakIndex = fitCount
        for index in stride(from: fitCount, through: lowerBound, by: -1) where preferredAfter.contains(characters[index - 1]) {
            breakIndex = index
            break
        }
        return (String(characters[0..<breakIndex]), String(characters[breakIndex...]))
    }
}
