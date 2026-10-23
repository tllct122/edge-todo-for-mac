// EdgeTodo — a to-do panel that hides at the right edge of your screen.
// Hover the right edge to slide it out. Data lives in ~/EdgeTodo/todos.json,
// so any AI (or you) can edit that file and the panel updates within a second.
// Pin it (📌) and it turns into Liquid Glass. Everything is customizable in Settings (⚙︎).

import SwiftUI
import AppKit
import Combine
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Color helpers

extension Color {
    /// "RRGGBB" or "RRGGBBAA" (with or without #)
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count == 6 { s += "FF" }
        let v = UInt64(s, radix: 16) ?? 0x000000FF
        self.init(.sRGB,
                  red: Double((v >> 24) & 0xFF) / 255,
                  green: Double((v >> 16) & 0xFF) / 255,
                  blue: Double((v >> 8) & 0xFF) / 255,
                  opacity: Double(v & 0xFF) / 255)
    }

    /// Perceived brightness 0…1 of a "RRGGBB[AA]" string.
    static func luminance(hex: String) -> Double {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count == 6 { s += "FF" }
        let v = UInt64(s, radix: 16) ?? 0
        let r = Double((v >> 24) & 0xFF) / 255
        let g = Double((v >> 16) & 0xFF) / 255
        let b = Double((v >> 8) & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    var hex: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        return String(format: "%02X%02X%02X%02X", r, g, b, a)
    }
}

// MARK: - Settings

enum FontChoice: String, CaseIterable {
    case mono, system, rounded, serif, custom
    var label: String {
        switch self {
        case .mono: return "Monospaced"
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .custom: return "Custom…"
        }
    }
}

enum WeightChoice: String, CaseIterable {
    case regular, medium, semibold, bold
    var label: String {
        switch self {
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        }
    }
    var weight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
    var bumped: WeightChoice {
        switch self {
        case .regular: return .medium
        case .medium: return .semibold
        case .semibold, .bold: return .bold
        }
    }
}

enum GlassChoice: String, CaseIterable {
    case clear, regular
    var label: String { self == .clear ? "Clear" : "Frosted" }
}

final class AppSettings: ObservableObject {
    private static let d = UserDefaults.standard

    enum Default {
        static let fontChoice = FontChoice.mono
        static let customFont = "Helvetica Neue"
        static let fontSize = 13.5
        static let weight = WeightChoice.medium
        static let textHex = "1C1C1EFF"
        static let pinnedTextHex = "000000E6"
        static let accentHex = "007AFFFF"
        static let tintHex = "FFFFFFFF"
        static let tintStrength = 0.0
        static let bgOpacity = 1.0
        static let glass = GlassChoice.clear
        static let pinnedBolder = true
        static let halo = true
        static let width = 320.0
        static let height = 480.0
        static let corner = 18.0
        static let soonDays = 2
        static let dueOnTop = true
        static let edgeGlow = true
        static let notify = true
        static let remindMinutes = 9 * 60      // 9:00 AM
        static let menuBadge = true
    }

    @Published var fontChoice: FontChoice { didSet { save() } }
    @Published var customFont: String { didSet { save() } }
    @Published var fontSize: Double { didSet { save() } }
    @Published var weight: WeightChoice { didSet { save() } }
    @Published var textHex: String { didSet { save() } }
    @Published var pinnedTextHex: String { didSet { save() } }
    @Published var accentHex: String { didSet { save() } }
    @Published var tintHex: String { didSet { save() } }
    @Published var tintStrength: Double { didSet { save() } }
    @Published var bgOpacity: Double { didSet { save() } }
    @Published var glass: GlassChoice { didSet { save() } }
    @Published var pinnedBolder: Bool { didSet { save() } }
    @Published var halo: Bool { didSet { save() } }
    @Published var width: Double { didSet { save() } }
    @Published var height: Double { didSet { save() } }
    @Published var corner: Double { didSet { save() } }
    @Published var soonDays: Int { didSet { save() } }
    @Published var dueOnTop: Bool { didSet { save() } }
    @Published var edgeGlow: Bool { didSet { save() } }
    @Published var notify: Bool { didSet { save() } }
    @Published var remindMinutes: Int { didSet { save() } }
    @Published var menuBadge: Bool { didSet { save() } }

    init() {
        let d = AppSettings.d
        fontChoice = FontChoice(rawValue: d.string(forKey: "fontChoice") ?? "") ?? Default.fontChoice
        customFont = d.string(forKey: "customFont") ?? Default.customFont
        fontSize = d.object(forKey: "fontSize") as? Double ?? Default.fontSize
        weight = WeightChoice(rawValue: d.string(forKey: "weight") ?? "") ?? Default.weight
        textHex = d.string(forKey: "textHex") ?? Default.textHex
        pinnedTextHex = d.string(forKey: "pinnedTextHex") ?? Default.pinnedTextHex
        accentHex = d.string(forKey: "accentHex") ?? Default.accentHex
        tintHex = d.string(forKey: "tintHex") ?? Default.tintHex
        tintStrength = d.object(forKey: "tintStrength") as? Double ?? Default.tintStrength
        bgOpacity = d.object(forKey: "bgOpacity") as? Double ?? Default.bgOpacity
        glass = GlassChoice(rawValue: d.string(forKey: "glass") ?? "") ?? Default.glass
        pinnedBolder = d.object(forKey: "pinnedBolder") as? Bool ?? Default.pinnedBolder
        halo = d.object(forKey: "halo") as? Bool ?? Default.halo
        width = d.object(forKey: "width") as? Double ?? Default.width
        height = d.object(forKey: "height") as? Double ?? Default.height
        corner = d.object(forKey: "corner") as? Double ?? Default.corner
        soonDays = d.object(forKey: "soonDays") as? Int ?? Default.soonDays
        dueOnTop = d.object(forKey: "dueOnTop") as? Bool ?? Default.dueOnTop
        edgeGlow = d.object(forKey: "edgeGlow") as? Bool ?? Default.edgeGlow
        notify = d.object(forKey: "notify") as? Bool ?? Default.notify
        remindMinutes = d.object(forKey: "remindMinutes") as? Int ?? Default.remindMinutes
        menuBadge = d.object(forKey: "menuBadge") as? Bool ?? Default.menuBadge
    }

    private func save() {
        let d = AppSettings.d
        d.set(fontChoice.rawValue, forKey: "fontChoice")
        d.set(customFont, forKey: "customFont")
        d.set(fontSize, forKey: "fontSize")
        d.set(weight.rawValue, forKey: "weight")
        d.set(textHex, forKey: "textHex")
        d.set(pinnedTextHex, forKey: "pinnedTextHex")
        d.set(accentHex, forKey: "accentHex")
        d.set(tintHex, forKey: "tintHex")
        d.set(tintStrength, forKey: "tintStrength")
        d.set(bgOpacity, forKey: "bgOpacity")
        d.set(glass.rawValue, forKey: "glass")
        d.set(pinnedBolder, forKey: "pinnedBolder")
        d.set(halo, forKey: "halo")
        d.set(width, forKey: "width")
        d.set(height, forKey: "height")
        d.set(corner, forKey: "corner")
        d.set(soonDays, forKey: "soonDays")
        d.set(dueOnTop, forKey: "dueOnTop")
        d.set(edgeGlow, forKey: "edgeGlow")
        d.set(notify, forKey: "notify")
        d.set(remindMinutes, forKey: "remindMinutes")
        d.set(menuBadge, forKey: "menuBadge")
    }

    func reset() {
        fontChoice = Default.fontChoice
        customFont = Default.customFont
        fontSize = Default.fontSize
        weight = Default.weight
        textHex = Default.textHex
        pinnedTextHex = Default.pinnedTextHex
        accentHex = Default.accentHex
        tintHex = Default.tintHex
        tintStrength = Default.tintStrength
        bgOpacity = Default.bgOpacity
        glass = Default.glass
        pinnedBolder = Default.pinnedBolder
        halo = Default.halo
        width = Default.width
        height = Default.height
        corner = Default.corner
        soonDays = Default.soonDays
        dueOnTop = Default.dueOnTop
        edgeGlow = Default.edgeGlow
        notify = Default.notify
        remindMinutes = Default.remindMinutes
        menuBadge = Default.menuBadge
    }

    /// White-ish text when pinned → switch the pinned panel to a dark look.
    var pinnedTextIsLight: Bool { Color.luminance(hex: pinnedTextHex) > 0.6 }

    func font(_ size: CGFloat, _ w: Font.Weight) -> Font {
        switch fontChoice {
        case .mono: return .system(size: size, weight: w, design: .monospaced)
        case .system: return .system(size: size, weight: w, design: .default)
        case .rounded: return .system(size: size, weight: w, design: .rounded)
        case .serif: return .system(size: size, weight: w, design: .serif)
        case .custom:
            if customFont.isEmpty { return .system(size: size, weight: w) }
            return Font.custom(customFont, size: size).weight(w)
        }
    }
}

// MARK: - Model

enum TodoStatus: String, Codable, CaseIterable {
    case todo, pending, completed, cancelled

    var label: String {
        switch self {
        case .todo: return "To-do"
        case .pending: return "Pending"
        case .completed: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

enum RepeatMode: String, Codable, CaseIterable {
    case none       // normal one-off task
    case anytime    // always there; every click logs a completion
    case every      // scheduled: every N days / weeks / months
}

enum RepeatUnit: String, Codable, CaseIterable {
    case day, week, month

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    func label(_ n: Int) -> String {
        n == 1 ? rawValue : "\(n) \(rawValue)s"
    }

    var short: String { rawValue.capitalized + "s" }
}

/// What kind of repeat a task has — e.g. every 3 days, every 2 weeks.
struct RepeatRule: Equatable {
    var mode: RepeatMode
    var every: Int = 1
    var unit: RepeatUnit = .day

    static let none = RepeatRule(mode: .none)
    static let anytime = RepeatRule(mode: .anytime)
    static let daily = RepeatRule(mode: .every, every: 1, unit: .day)
    static let weekly = RepeatRule(mode: .every, every: 1, unit: .week)
    static let monthly = RepeatRule(mode: .every, every: 1, unit: .month)

    /// Presets the ↻ button in the add field cycles through.
    static let cycle: [RepeatRule] = [.none, .anytime, .daily, .weekly, .monthly]

    var next: RepeatRule {
        let i = RepeatRule.cycle.firstIndex(of: self) ?? 0
        return RepeatRule.cycle[(i + 1) % RepeatRule.cycle.count]
    }

    var isDaily: Bool { mode == .every && every == 1 && unit == .day }

    var label: String {
        switch mode {
        case .none: return "No repeat"
        case .anytime: return "Repeat anytime (log each time)"
        case .every: return "Every \(unit.label(every))"
        }
    }

    var icon: String {
        switch mode {
        case .none, .anytime: return "arrow.triangle.2.circlepath"
        case .every: return isDaily ? "sun.max" : "calendar"
        }
    }

    /// Parses "3d", "2w", "1m", "3days", "2 weeks"…
    static func parse(_ s: String) -> RepeatRule? {
        let t = s.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let digits = t.prefix { $0.isNumber }
        guard let n = Int(digits), n > 0 else { return nil }
        let rest = t.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        let unit: RepeatUnit
        switch rest {
        case "d", "day", "days": unit = .day
        case "w", "wk", "week", "weeks": unit = .week
        case "m", "mo", "month", "months": unit = .month
        default: return nil
        }
        return RepeatRule(mode: .every, every: min(n, 999), unit: unit)
    }
}

let isoFormatter = ISO8601DateFormatter()

struct TodoItem: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var category: String
    var status: TodoStatus
    var created: String?
    var repeatMode: RepeatMode
    var every: Int                 // for .every: how many units
    var unit: RepeatUnit           // for .every: day / week / month
    var lastDone: String?
    var history: [String]          // ISO timestamps of every check-in (repeating items)
    var pinned: Bool               // shown in the 📌 section at the top
    var due: String?               // "2026-10-25" or "2026-10-25 18:00" (one-off tasks)

    enum CodingKeys: String, CodingKey {
        case id, title, category, status, created, lastDone, history, pinned, every, unit, due
        case repeatMode = "repeat"
    }

    init(id: String = UUID().uuidString, title: String, category: String,
         status: TodoStatus = .todo, created: String? = nil,
         rule: RepeatRule = .none, due: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.status = status
        self.created = created
        self.repeatMode = rule.mode
        self.every = rule.every
        self.unit = rule.unit
        self.lastDone = nil
        self.history = []
        self.pinned = false
        self.due = due
    }

    // Lenient decoding: an AI only needs to write "title"; everything else has defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = try c.decode(String.self, forKey: .title)
        let cat = (try? c.decode(String.self, forKey: .category)) ?? "inbox"
        category = cat.isEmpty ? "inbox" : cat
        status = (try? c.decode(TodoStatus.self, forKey: .status)) ?? .todo
        created = try? c.decode(String.self, forKey: .created)

        every = max(1, (try? c.decode(Int.self, forKey: .every)) ?? 1)
        unit = (try? c.decode(RepeatUnit.self, forKey: .unit)) ?? .day
        // "repeat" also accepts the shortcuts daily / weekly / monthly
        switch ((try? c.decode(String.self, forKey: .repeatMode)) ?? "none").lowercased() {
        case "anytime": repeatMode = .anytime
        case "every": repeatMode = .every
        case "daily": repeatMode = .every; unit = .day
        case "weekly": repeatMode = .every; unit = .week
        case "monthly": repeatMode = .every; unit = .month
        default: repeatMode = .none
        }

        history = (try? c.decode([String].self, forKey: .history)) ?? []
        lastDone = (try? c.decode(String.self, forKey: .lastDone)) ?? history.last
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
        // accept any date format DueDate understands, store it normalized
        due = (try? c.decode(String.self, forKey: .due)).flatMap { DueDate.normalize($0) }
    }

    // Keep the JSON tidy: only write repeat fields for repeating items.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(category, forKey: .category)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(created, forKey: .created)
        if pinned { try c.encode(true, forKey: .pinned) }
        try c.encodeIfPresent(due, forKey: .due)
        if repeatMode != .none {
            try c.encode(repeatMode, forKey: .repeatMode)
            if repeatMode == .every {
                try c.encode(every, forKey: .every)
                try c.encode(unit, forKey: .unit)
            }
            try c.encodeIfPresent(lastDone, forKey: .lastDone)
            if !history.isEmpty { try c.encode(history, forKey: .history) }
        }
    }

    var rule: RepeatRule {
        get { RepeatRule(mode: repeatMode, every: every, unit: unit) }
        set { repeatMode = newValue.mode; every = newValue.every; unit = newValue.unit }
    }

    var isRepeating: Bool { repeatMode != .none }

    var lastDoneDate: Date? { lastDone.flatMap { isoFormatter.date(from: $0) } }

    /// For scheduled tasks: the day it becomes due again (start of that day).
    var nextDue: Date? {
        guard repeatMode == .every, let d = lastDoneDate else { return nil }
        let cal = Calendar.current
        return cal.date(byAdding: unit.component, value: every, to: cal.startOfDay(for: d))
    }

    /// Scheduled task that's been done and isn't due yet.
    func isDoneForNow(_ now: Date) -> Bool {
        guard let due = nextDue else { return false }
        return now < due
    }

    /// Whole days from `nextDue` to today (0 = due today). nil if not yet due / never done.
    func daysOverdue(_ now: Date) -> Int? {
        guard let due = nextDue, now >= due else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: due, to: cal.startOfDay(for: now)).day
    }

    // MARK: Due date

    /// Parsed due date. Only one-off tasks use it.
    var dueInfo: (date: Date, hasTime: Bool)? {
        guard repeatMode == .none, let d = due else { return nil }
        return DueDate.decode(d)
    }

    /// The moment it's late: the set time, or the end of the due day.
    var dueDeadline: Date? {
        guard let info = dueInfo else { return nil }
        if info.hasTime { return info.date }
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: info.date))
    }

    func urgency(_ now: Date, soonDays: Int) -> Urgency {
        guard status == .todo || status == .pending,
              let d = dueInfo?.date, let deadline = dueDeadline else { return .noDue }
        if now >= deadline { return .overdue }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        if days <= 0 { return .today }
        if days <= soonDays { return .soon }
        return .later
    }

    /// Consecutive days with a check-in, ending today (or yesterday if not done yet today).
    func streak(_ now: Date) -> Int {
        let cal = Calendar.current
        let days = Set(history.compactMap { isoFormatter.date(from: $0) }.map { cal.startOfDay(for: $0) })
        var day = cal.startOfDay(for: now)
        if !days.contains(day), let y = cal.date(byAdding: .day, value: -1, to: day) { day = y }
        var n = 0
        while days.contains(day) {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }
}

// MARK: - Due dates

enum Urgency: Int, Comparable {
    case noDue, later, soon, today, overdue
    static func < (a: Urgency, b: Urgency) -> Bool { a.rawValue < b.rawValue }

    /// Needs attention → floats to the top, gets colored
    var isUrgent: Bool { self >= .soon }

    var color: Color {
        switch self {
        case .overdue: return Color(hex: "FF3B30")
        case .today: return Color(hex: "FF9500")
        case .soon: return Color(hex: "E0A100")
        case .later, .noDue: return .clear
        }
    }
}

enum DueDate {
    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = pattern
        return f
    }
    private static let dayOnly = fmt("yyyy-MM-dd")
    private static let dayTime = fmt("yyyy-MM-dd HH:mm")
    private static let dayTimeT = fmt("yyyy-MM-dd'T'HH:mm")

    static func encode(_ d: Date, hasTime: Bool) -> String {
        (hasTime ? dayTime : dayOnly).string(from: d)
    }

    static func decode(_ s: String) -> (date: Date, hasTime: Bool)? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.count >= 16 {
            let head = String(t.prefix(16))
            if let d = dayTime.date(from: head) ?? dayTimeT.date(from: head) { return (d, true) }
        }
        if let d = isoFormatter.date(from: t) { return (d, true) }
        if let d = dayOnly.date(from: String(t.prefix(10))) { return (d, false) }
        return nil
    }

    static func normalize(_ s: String) -> String? {
        decode(s).map { encode($0.date, hasTime: $0.hasTime) }
    }

    // ---- typing shortcuts: "/due fri", "/due 10/25 6pm", "/due 3d", "/today", "/tmr" ----

    private static let weekdays: [String: Int] = [
        "sun": 1, "sunday": 1, "mon": 2, "monday": 2, "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "wednesday": 4, "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6, "sat": 7, "saturday": 7,
    ]

    /// A day word → start of that day.
    static func parseDay(_ token: String, now: Date) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let t = token.lowercased()
        switch t {
        case "today", "tod": return today
        case "tomorrow", "tmr", "tmrw", "tom": return cal.date(byAdding: .day, value: 1, to: today)
        default: break
        }
        if let wd = weekdays[t] {          // next occurrence, today counts
            let diff = (wd - cal.component(.weekday, from: today) + 7) % 7
            return cal.date(byAdding: .day, value: diff, to: today)
        }
        // "+3d", "3d", "2w", "1m" → that many days / weeks / months from today
        let rel = t.hasPrefix("+") ? String(t.dropFirst()) : t
        if let r = RepeatRule.parse(rel) {
            return cal.date(byAdding: r.unit.component, value: r.every, to: today)
        }
        // "2026-10-25"
        if let d = dayOnly.date(from: t) { return d }
        // "10/25", "25/10", "10/25/2026"
        let parts = t.split(separator: "/").compactMap { Int($0) }
        if parts.count == 2 || parts.count == 3 {
            var (m, d) = (parts[0], parts[1])
            if m > 12 && d <= 12 { swap(&m, &d) }          // 25/10 → Oct 25
            var comps = DateComponents(month: m, day: d)
            if parts.count == 3 {
                comps.year = parts[2] < 100 ? 2000 + parts[2] : parts[2]
                return cal.date(from: comps)
            }
            comps.year = cal.component(.year, from: today)
            guard var date = cal.date(from: comps) else { return nil }
            if date < today, let next = cal.date(byAdding: .year, value: 1, to: date) { date = next }
            return date
        }
        return nil
    }

    /// "18:00", "6pm", "6:30pm", "noon" → (hour, minute)
    static func parseTime(_ token: String) -> (Int, Int)? {
        var t = token.lowercased()
        if t == "noon" { return (12, 0) }
        if t == "midnight" { return (23, 59) }
        var pm = false, am = false
        if t.hasSuffix("pm") { pm = true; t.removeLast(2) } else if t.hasSuffix("am") { am = true; t.removeLast(2) }
        let parts = t.split(separator: ":").map(String.init)
        guard let h0 = Int(parts.first ?? ""), parts.count <= 2 else { return nil }
        let m = parts.count == 2 ? (Int(parts[1]) ?? -1) : 0
        if parts.count == 1 && !(am || pm) { return nil }  // plain "6" is ambiguous
        var h = h0
        if pm && h < 12 { h += 12 }
        if am && h == 12 { h = 0 }
        guard (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }

    /// Reads a day (and an optional time right after it) from tokens[i...].
    /// Returns the stored string and how many tokens were used.
    static func parse(_ tokens: [String], at i: Int, now: Date) -> (String, Int)? {
        guard i < tokens.count, let day = parseDay(tokens[i], now: now) else { return nil }
        if i + 1 < tokens.count, let hm = parseTime(tokens[i + 1]),
           let d = Calendar.current.date(bySettingHour: hm.0, minute: hm.1, second: 0, of: day) {
            return (encode(d, hasTime: true), 2)
        }
        return (encode(day, hasTime: false), 1)
    }

    /// Subtitle text for a due date.
    static func label(_ date: Date, hasTime: Bool, urgency: Urgency, now: Date) -> String {
        let cal = Calendar.current
        let tf = DateFormatter()
        tf.locale = Locale(identifier: "en_US")
        tf.dateFormat = "h:mm a"
        let time = hasTime ? " \(tf.string(from: date))" : ""
        let wf = DateFormatter()
        wf.locale = Locale(identifier: "en_US")
        wf.dateFormat = "EEE"
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0

        switch urgency {
        case .overdue:
            if days == 0 { return "⏰ overdue · was due\(time)" }
            let n = -days
            return "⏰ overdue \(n) day\(n == 1 ? "" : "s") · \(shortDate(date, now: now))"
        case .today:
            return "🔥 due today\(time)"
        case .soon:
            if days == 1 { return "📅 due tomorrow\(time)" }
            return "📅 due in \(days) days · \(wf.string(from: date))\(time)"
        case .later, .noDue:
            return "📅 due \(wf.string(from: date)), \(shortDate(date, now: now))\(time)"
        }
    }
}

/// "Oct 29", or "Oct 29, 2027" if not this year
func shortDate(_ d: Date, now: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    let sameYear = Calendar.current.component(.year, from: d) == Calendar.current.component(.year, from: now)
    f.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
    return f.string(from: d)
}

/// "today 9:12 AM", "yesterday", "3 days ago", "12 days ago · Oct 10"
func relativeDay(_ d: Date, now: Date) -> String {
    let cal = Calendar.current
    let time = DateFormatter()
    time.locale = Locale(identifier: "en_US")
    time.dateFormat = "h:mm a"
    if cal.isDate(d, inSameDayAs: now) { return "today \(time.string(from: d))" }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: now)).day ?? 0
    if days == 1 { return "yesterday" }
    if days < 7 { return "\(days) days ago" }
    let md = DateFormatter()
    md.locale = Locale(identifier: "en_US")
    md.dateFormat = "MMM d"
    return "\(days) days ago · \(md.string(from: d))"
}

struct TodoFile: Codable {
    var todos: [TodoItem]
}

func orderedUnique(_ a: [String]) -> [String] {
    var seen = Set<String>()
    return a.filter { seen.insert($0).inserted }
}

// MARK: - Store (reads / writes / watches ~/EdgeTodo/todos.json)

final class TodoStore: ObservableObject {
    @Published private(set) var todos: [TodoItem] = []
    let folderURL: URL
    let fileURL: URL
    private var lastModified: Date?
    private var timer: Timer?

    init() {
        let fm = FileManager.default
        folderURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("EdgeTodo", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("todos.json")
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)

        if fm.fileExists(atPath: fileURL.path) {
            load()
        } else {
            todos = TodoStore.sample
            save()
        }

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.reloadIfChanged()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func modDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
    }

    private func reloadIfChanged() {
        if modDate() != lastModified { load() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        // If the file is mid-write or invalid, keep what we have and retry next tick.
        guard let file = try? JSONDecoder().decode(TodoFile.self, from: data) else { return }
        if file.todos != todos { todos = file.todos }
        lastModified = modDate()
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? enc.encode(TodoFile(todos: todos)) else { return }
        try? data.write(to: fileURL, options: .atomic)
        lastModified = modDate()
    }

    private static func now() -> String {
        isoFormatter.string(from: Date())
    }

    // "buy milk #life"          -> title "buy milk", category "life"
    // "gym #health /repeat"     -> repeats anytime
    // "vitamins /daily"         -> every day   (/weekly, /monthly too)
    // "water plants /3d"        -> every 3 days (/2w = 2 weeks, /1m = 1 month)
    // "haircut /every 6 weeks"  -> every 6 weeks
    // "essay /due fri"           -> due this Friday
    // "submit hw /due 10/25 6pm" -> due Oct 25 at 6 PM   (also /today, /tmr, /due 3d)
    func add(_ raw: String, status: TodoStatus, rule: RepeatRule = .none, due: String? = nil) {
        var due = due
        let now = Date()
        var words: [String] = []
        var category = "inbox"
        var rule = rule
        let tokens = raw.split(separator: " ").map(String.init)
        var i = 0
        while i < tokens.count {
            let w = tokens[i]
            let lower = w.lowercased()
            if w.hasPrefix("#") && w.count > 1 {
                category = String(w.dropFirst()).lowercased()
            } else if lower == "/daily" {
                rule = .daily
            } else if lower == "/weekly" {
                rule = .weekly
            } else if lower == "/monthly" {
                rule = .monthly
            } else if lower == "/repeat" || lower == "/anytime" {
                rule = .anytime
            } else if lower == "/today" || lower == "/tmr" || lower == "/tmrw" || lower == "/tomorrow" {
                // "/tmr" or "/tmr 6pm"
                if let r = DueDate.parse([String(lower.dropFirst())] + tokens[(i + 1)...], at: 0, now: now) {
                    due = r.0; i += r.1 - 1
                }
            } else if lower == "/due" || lower == "/by" || lower == "/ddl" {
                if let r = DueDate.parse(tokens, at: i + 1, now: now) {
                    due = r.0; i += r.1
                }
            } else if lower == "/every" {
                // "/every 3d" or "/every 3 days"
                if i + 1 < tokens.count, let r = RepeatRule.parse(tokens[i + 1]) {
                    rule = r; i += 1
                } else if i + 2 < tokens.count, let r = RepeatRule.parse(tokens[i + 1] + tokens[i + 2]) {
                    rule = r; i += 2
                }
            } else if w.hasPrefix("/"), let r = RepeatRule.parse(w) {
                rule = r
            } else {
                words.append(w)
            }
            i += 1
        }
        let title = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        // due dates are for one-off tasks
        todos.append(TodoItem(title: title, category: category, status: status,
                              created: TodoStore.now(), rule: rule,
                              due: rule.mode == .none ? due : nil))
        save()
    }

    func checkIn(_ id: String) {
        update(id) { item in
            let stamp = TodoStore.now()
            item.history.append(stamp)
            if item.history.count > 400 { item.history.removeFirst(item.history.count - 400) }
            item.lastDone = stamp
        }
    }

    func undoCheckIn(_ id: String) {
        update(id) { item in
            if !item.history.isEmpty { item.history.removeLast() }
            item.lastDone = item.history.last
        }
    }

    func setRepeat(_ id: String, _ rule: RepeatRule) {
        update(id) { item in
            item.rule = rule
            if rule.mode != .none { item.due = nil }
            if rule.mode != .none && (item.status == .completed || item.status == .cancelled) {
                item.status = .todo
            }
        }
    }

    private func update(_ id: String, _ change: (inout TodoItem) -> Void) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        change(&todos[i])
        save()
    }

    func toggle(_ id: String) {
        guard let item = todos.first(where: { $0.id == id }) else { return }
        switch item.repeatMode {
        case .none:
            update(id) { $0.status = ($0.status == .completed) ? .todo : .completed }
        case .anytime:
            checkIn(id)                                  // every click logs a new completion
        case .every:
            // done for this period → clicking again undoes; otherwise log it
            if item.isDoneForNow(Date()) { undoCheckIn(id) } else { checkIn(id) }
        }
    }
    func setStatus(_ id: String, _ s: TodoStatus) { update(id) { $0.status = s } }
    func setCategory(_ id: String, _ c: String) { update(id) { $0.category = c } }
    func togglePinned(_ id: String) { update(id) { $0.pinned.toggle() } }
    func setDue(_ id: String, _ due: String?) { update(id) { $0.due = due } }

    /// Drag & drop: put `id` where `targetId` is. Dropping onto a task in another
    /// category moves it into that category; dropping into the pinned section pins it.
    func move(_ id: String, onto targetId: String) {
        guard id != targetId,
              let from = todos.firstIndex(where: { $0.id == id }),
              let to = todos.firstIndex(where: { $0.id == targetId }) else { return }
        let target = todos[to]
        var item = todos.remove(at: from)
        if target.pinned {
            item.pinned = true
        } else {
            item.pinned = false
            item.category = target.category
        }
        let newIndex = todos.firstIndex(where: { $0.id == targetId }) ?? todos.count
        todos.insert(item, at: from < to ? newIndex + 1 : newIndex)
        save()
    }

    /// Move one step up (-1) or down (+1) among the tasks shown next to it.
    func step(_ id: String, _ direction: Int) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        let item = todos[i]
        func sameGroup(_ o: TodoItem) -> Bool {
            o.status == item.status && o.pinned == item.pinned && (item.pinned || o.category == item.category)
        }
        var j = i + direction
        while j >= 0 && j < todos.count {
            if sameGroup(todos[j]) {
                todos.swapAt(i, j)
                save()
                return
            }
            j += direction
        }
    }
    func delete(_ id: String) { todos.removeAll { $0.id == id }; save() }

    func items(_ s: TodoStatus) -> [TodoItem] { todos.filter { $0.status == s } }
    var categories: [String] { orderedUnique(todos.map { $0.category }) }

    static let sample: [TodoItem] = [
        TodoItem(title: "weekly report", category: "work"),
        TodoItem(title: "gym workout", category: "health", rule: .anytime),
        TodoItem(title: "drink 2L water", category: "health", rule: .daily),
        TodoItem(title: "change bedsheets", category: "life", rule: RepeatRule(mode: .every, every: 2, unit: .week)),
        TodoItem(title: "get groceries", category: "life"),
        TodoItem(title: "organize raw clips", category: "content"),
        TodoItem(title: "finish essay", category: "study",
                 due: DueDate.encode(Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(), hasTime: false)),
        TodoItem(title: "hover the right edge to open me ✿", category: "study"),
    ]
}

final class PanelState: ObservableObject {
    @Published var pinned = false
    @Published var previewing = false      // true while the Settings window is open
    @Published var panelKey = false        // true while the panel itself has focus
    var openSettings: (() -> Void)?
}

// MARK: - Clear glass (no blur — you can see straight through it)

struct ClearGlass: View {
    let corner: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            // barely-there body so the glass reads as a surface
            shape.fill(Color.white.opacity(0.05))
            // diagonal sheen
            shape.fill(LinearGradient(
                colors: [Color.white.opacity(0.22), Color.white.opacity(0.0), Color.white.opacity(0.0), Color.white.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            // bright rim, like light catching the edge of glass
            shape.strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0.18), Color.white.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)
            // faint inner line for depth
            shape.inset(by: 1.3).strokeBorder(Color.black.opacity(0.07), lineWidth: 0.6)
        }
    }
}

// MARK: - Palette (derived from settings + pinned state)

struct Palette {
    let s: AppSettings
    let pinned: Bool

    var primary: Color { Color(hex: pinned ? s.pinnedTextHex : s.textHex) }
    var secondary: Color { primary.opacity(0.62) }
    var accent: Color { Color(hex: s.accentHex) }
    /// Dark look: pinned with white-ish text
    var dark: Bool { pinned && s.pinnedTextIsLight }
    /// Fill for chips, input field and hover (contrasts with the text)
    var surface: Color { dark ? Color.black : Color.white }
    /// Glow behind text: dark glow for light text, white glow for dark text
    var halo: Color { dark ? Color.black.opacity(0.6) : Color.white.opacity(0.7) }
    var weight: Font.Weight { (pinned && s.pinnedBolder ? s.weight.bumped : s.weight).weight }

    func font(_ scale: CGFloat, bold: Bool = false) -> Font {
        s.font(CGFloat(s.fontSize) * scale, bold ? .bold : weight)
    }
}

// MARK: - Panel views

struct PanelView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var state: PanelState
    @ObservedObject var settings: AppSettings
    @State private var tab: TodoStatus = .todo
    @State private var newText = ""
    @State private var newRepeat: RepeatRule = .none
    @State private var dragging: String?    // id of the task being dragged
    @State private var newDue: String?      // due date picked for the task being typed
    @State private var pickingDue = false
    @State private var pulse = false
    @State private var now = Date()      // ticks so "x days ago" and daily resets stay current
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var pal: Palette { Palette(s: settings, pinned: state.pinned) }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM d, EEEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            tabBar
            Divider().opacity(0.5)
            ScrollView(.vertical, showsIndicators: false) {
                list.padding(.vertical, 2)
            }
            addField
        }
        .padding(16)
        .frame(width: CGFloat(settings.width), height: CGFloat(settings.height))
        // A soft glow behind each glyph keeps text legible over busy wallpapers.
        .shadow(color: (state.pinned && settings.halo) ? pal.halo : Color.clear, radius: 1.5)
        .background(
            ZStack {
                // Pinned + not focused → pure see-through glass
                if state.pinned && !state.panelKey {
                    ClearGlass(corner: CGFloat(settings.corner))
                        .opacity(settings.bgOpacity)
                        .transition(.opacity)
                }
                RoundedRectangle(cornerRadius: CGFloat(settings.corner), style: .continuous)
                    .fill(Color(hex: settings.tintHex).opacity(settings.tintStrength))
            }
        )
        // Glowing strip on the left edge — still visible when the panel is tucked away
        .overlay(alignment: .leading) { edgeGlow }
        .animation(.easeInOut(duration: 0.2), value: state.pinned)
        .animation(.easeInOut(duration: 0.2), value: state.panelKey)
        .onReceive(clock) { now = $0 }
    }

    /// Most urgent due date across all open tasks.
    private var topUrgency: Urgency {
        store.todos.map { $0.urgency(now, soonDays: settings.soonDays) }.max() ?? .noDue
    }

    @ViewBuilder
    private var edgeGlow: some View {
        let u = topUrgency
        if settings.edgeGlow && u >= .today {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(u.color)
                .frame(width: 4)
                .padding(.vertical, max(CGFloat(settings.corner), 10))
                .padding(.leading, 1)
                .shadow(color: u.color.opacity(0.9), radius: 4)
                .opacity(pulse ? 1 : 0.45)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
                .onDisappear { pulse = false }
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack {
            Button {
                state.openSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pal.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Spacer()
            TimelineView(.periodic(from: Date(), by: 60)) { ctx in
                Text(PanelView.dateFormatter.string(from: ctx.date))
                    .font(pal.font(0.93))
                    .foregroundColor(pal.secondary)
            }
            Spacer()

            Button {
                state.pinned.toggle()
            } label: {
                Image(systemName: state.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(state.pinned ? pal.accent : pal.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Pin: keep open as Liquid Glass")
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(TodoStatus.allCases, id: \.self) { s in
                Button {
                    tab = s
                } label: {
                    Text(s.label)
                        .font(pal.font(0.89, bold: tab == s))
                        .foregroundColor(tab == s ? pal.primary : pal.secondary)
                        .lineLimit(1)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule().fill(tab == s ? pal.surface.opacity(pal.dark ? 0.35 : (state.pinned ? 0.55 : 0.75)) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var list: some View {
        let items = store.items(tab)
        if items.isEmpty {
            Text(tab == .todo ? "all clear ✿" : "nothing here")
                .font(pal.font(1.0))
                .foregroundColor(pal.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            // ⏰ overdue / due today / due soon float to the top, soonest first
            let dueItems = settings.dueOnTop
                ? items.filter { $0.urgency(now, soonDays: settings.soonDays).isUrgent }
                    .sorted { ($0.dueDeadline ?? .distantFuture) < ($1.dueDeadline ?? .distantFuture) }
                : []
            let dueIds = Set(dueItems.map { $0.id })
            let dueTop = dueItems.map { $0.urgency(now, soonDays: settings.soonDays) }.max() ?? .soon
            let pinnedItems = sinkDoneDaily(items.filter { $0.pinned && !dueIds.contains($0.id) })
            let rest = items.filter { !$0.pinned && !dueIds.contains($0.id) }
            VStack(alignment: .leading, spacing: 14) {
                if !dueItems.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("⏰ due soon")
                            .font(pal.font(1.04, bold: true))
                            .foregroundColor(pal.primary)
                            .padding(.leading, 2)
                            .padding(.bottom, 2)
                        ForEach(dueItems) { item in
                            TodoRow(item: item, store: store, pal: pal, now: now, showCategory: true)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(dueTop.color.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(dueTop.color.opacity(0.35), lineWidth: 1))
                }
                // 📌 Pinned section always sits on top
                if !pinnedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("📌 pinned")
                            .font(pal.font(1.04, bold: true))
                            .foregroundColor(pal.primary)
                            .padding(.leading, 2)
                            .padding(.bottom, 2)
                        ForEach(pinnedItems) { item in
                            draggable(TodoRow(item: item, store: store, pal: pal, now: now, showCategory: true), item)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(pal.accent.opacity(0.08)))
                }
                ForEach(orderedUnique(rest.map { $0.category }), id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cat)
                            .font(pal.font(1.04, bold: true))
                            .foregroundColor(pal.primary)
                            .padding(.leading, 2)
                            .padding(.bottom, 2)
                        ForEach(sinkDoneDaily(rest.filter { $0.category == cat })) { item in
                            draggable(TodoRow(item: item, store: store, pal: pal, now: now), item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.15), value: store.todos)
        }
    }

    /// Lets a row be dragged and accept other rows dropped onto it.
    private func draggable(_ row: TodoRow, _ item: TodoItem) -> some View {
        row
            .onDrag {
                dragging = item.id
                return NSItemProvider(object: item.id as NSString)
            }
            .onDrop(of: [UTType.text], delegate: RowDropDelegate(target: item, dragging: $dragging, store: store))
    }

    /// Scheduled tasks that are done for now sink to the bottom of their group.
    private func sinkDoneDaily(_ group: [TodoItem]) -> [TodoItem] {
        group.filter { !$0.isDoneForNow(now) } + group.filter { $0.isDoneForNow(now) }
    }

    private var addPlaceholder: String {
        switch newRepeat.mode {
        case .none:
            if let d = newDue, let info = DueDate.decode(d) {
                return "Add task · " + DueDate.label(info.date, hasTime: info.hasTime, urgency: .later, now: now)
                    .replacingOccurrences(of: "📅 ", with: "")
            }
            return "Add new todo   #category"
        case .anytime: return "Add repeating task   #category"
        case .every: return "Add task · \(newRepeat.label.lowercased())"
        }
    }

    private var addField: some View {
        VStack(alignment: .leading, spacing: 8) {
            if pickingDue {
                DueEditor(pal: pal, initial: newDue,
                          onSet: { d in
                              newDue = d
                              if d != nil { newRepeat = .none }   // due dates are for one-off tasks
                              pickingDue = false
                          },
                          onCancel: { pickingDue = false })
                    .padding(.horizontal, 4)
            }
            addRow
        }
    }

    private var addRow: some View {
        HStack(spacing: 6) {
            TextField(addPlaceholder, text: $newText)
                .textFieldStyle(.plain)
                .font(pal.font(1.0))
                .foregroundColor(pal.primary)
                .onSubmit(submit)
            // Due date picker
            Button {
                pickingDue.toggle()
            } label: {
                Image(systemName: newDue == nil ? "calendar" : "calendar.badge.clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(newDue == nil && !pickingDue ? pal.secondary.opacity(0.6) : pal.accent)
            }
            .buttonStyle(.plain)
            .help("Due date — or type /due fri, /due 10/25 6pm, /today, /tmr")
            // Cycles: no repeat → anytime → every day → every week → every month
            Button {
                newRepeat = newRepeat.next
                if newRepeat.mode != .none { newDue = nil }
            } label: {
                Image(systemName: newRepeat.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(newRepeat.mode == .none ? pal.secondary.opacity(0.6) : pal.accent)
            }
            .buttonStyle(.plain)
            .help("Repeat: \(newRepeat.label)  — or type /3d, /2w, /1m")
            Button(action: submit) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pal.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .background(RoundedRectangle(cornerRadius: 10).fill(
            state.pinned ? pal.surface.opacity(pal.dark ? 0.3 : 0.35) : Color.primary.opacity(0.05)))
    }

    private func submit() {
        let status: TodoStatus = (tab == .pending) ? .pending : .todo
        store.add(newText, status: status, rule: newRepeat, due: newDue)
        newText = ""
        newRepeat = .none
        newDue = nil
        pickingDue = false
        if tab != .pending { tab = .todo }
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    let pal: Palette
    let now: Date
    var showCategory: Bool = false
    @State private var hover = false
    @State private var justLogged = false
    @State private var editingRule = false
    @State private var editEvery = 1
    @State private var editUnit: RepeatUnit = .day
    @State private var editingDue = false

    private var urgency: Urgency { item.urgency(now, soonDays: pal.s.soonDays) }

    private var dueText: String? {
        guard let info = item.dueInfo else { return nil }
        return DueDate.label(info.date, hasTime: info.hasTime, urgency: urgency, now: now)
    }

    private var isDone: Bool { item.status == .completed || item.status == .cancelled }
    private var doneForNow: Bool { item.isDoneForNow(now) }
    private var isOverdue: Bool { !item.rule.isDaily && (item.daysOverdue(now) ?? 0) > 0 }
    private var isCustomRule: Bool { item.repeatMode == .every && !RepeatRule.cycle.contains(item.rule) }

    private var checkIcon: String {
        switch item.repeatMode {
        case .none: return item.status == .completed ? "checkmark.square.fill" : "square"
        case .every: return doneForNow ? "checkmark.square.fill" : "square"
        case .anytime: return justLogged ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle"
        }
    }

    private var checkHighlighted: Bool {
        item.status == .completed || doneForNow || justLogged
    }

    /// Small line under the title: "#category" in the pinned section, plus repeat info
    private var subtitle: String? {
        let parts = [showCategory ? "#\(item.category)" : nil, repeatInfo, dueText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }

    private var repeatInfo: String? {
        switch item.repeatMode {
        case .none:
            return nil
        case .anytime:
            guard let d = item.lastDoneDate else { return "↻ not done yet" }
            return "↻ last: \(relativeDay(d, now: now)) · \(item.history.count)×"
        case .every:
            let r = item.rule
            if r.isDaily {
                let s = item.streak(now)
                let fire = s >= 2 ? " · 🔥 \(s) days" : ""
                if doneForNow, let d = item.lastDoneDate { return "☀︎ done \(relativeDay(d, now: now))\(fire)" }
                return "☀︎ daily\(fire)"
            }
            let every = "every \(r.unit.label(r.every))"
            if doneForNow, let d = item.lastDoneDate, let due = item.nextDue {
                return "🗓 done \(relativeDay(d, now: now)) · next \(shortDate(due, now: now))"
            }
            if let od = item.daysOverdue(now) {
                if od == 0 { return "🗓 \(every) · due today" }
                return "⏰ overdue \(od) day\(od == 1 ? "" : "s") · \(every)"
            }
            return "🗓 \(every)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 9) {
                Button {
                    store.toggle(item.id)
                    if item.repeatMode == .anytime {
                        justLogged = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justLogged = false }
                    }
                } label: {
                    Image(systemName: checkIcon)
                        .font(.system(size: CGFloat(pal.s.fontSize) * 1.04, weight: .medium))
                        .foregroundColor(checkHighlighted ? pal.accent : pal.secondary)
                        .padding(.top, 1)
                }
                .buttonStyle(.plain)
                .help(item.repeatMode == .anytime ? "Log a completion" : "")

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .strikethrough(isDone)
                        .font(pal.font(1.0))
                        .foregroundColor((isDone || doneForNow) ? pal.secondary : pal.primary)
                        .lineLimit(2)
                    if let sub = subtitle {
                        Text(sub)
                            .font(pal.font(0.8, bold: urgency >= .today))
                            .foregroundColor(urgency.isUrgent ? urgency.color
                                             : (isOverdue ? Color.red.opacity(0.85) : pal.secondary))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            if editingRule { ruleEditor }
            if editingDue {
                DueEditor(pal: pal, initial: item.due,
                          onSet: { d in store.setDue(item.id, d); editingDue = false },
                          onCancel: { editingDue = false })
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(
            (pal.pinned ? pal.surface : Color.primary).opacity(hover || editingRule || editingDue ? (pal.pinned ? 0.3 : 0.06) : 0)))
        // urgent tasks get a tinted background and a colored bar on the left
        .background(RoundedRectangle(cornerRadius: 7).fill(urgency >= .today ? urgency.color.opacity(0.12) : Color.clear))
        .overlay(alignment: .leading) {
            if urgency.isUrgent {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(urgency.color)
                    .frame(width: 3)
                    .padding(.vertical, 3)
            }
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .contextMenu {
            ForEach(TodoStatus.allCases.filter { $0 != item.status }, id: \.self) { s in
                Button("Move to \(s.label)") { store.setStatus(item.id, s) }
            }
            Divider()
            Menu("Category") {
                ForEach(store.categories, id: \.self) { c in
                    Button(c) { store.setCategory(item.id, c) }
                }
            }
            Button("Move Up") { withAnimation(.easeOut(duration: 0.15)) { store.step(item.id, -1) } }
            Button("Move Down") { withAnimation(.easeOut(duration: 0.15)) { store.step(item.id, 1) } }
            Divider()
            Button(item.pinned ? "Unpin from Top" : "Pin to Top") { store.togglePinned(item.id) }
            if item.repeatMode == .none {
                Menu("Due Date") {
                    Button("Today") { store.setDue(item.id, quickDue(0)) }
                    Button("Tomorrow") { store.setDue(item.id, quickDue(1)) }
                    Button("In 3 Days") { store.setDue(item.id, quickDue(3)) }
                    Button("Next Week") { store.setDue(item.id, quickDue(7)) }
                    Button("Pick a Date…") { editingDue = true }
                    if item.due != nil {
                        Divider()
                        Button("Remove Due Date") { store.setDue(item.id, nil) }
                    }
                }
            }
            Menu("Repeat") {
                ForEach(RepeatRule.cycle, id: \.label) { r in
                    Button((r == item.rule ? "✓ " : "    ") + r.label) { store.setRepeat(item.id, r) }
                }
                Divider()
                Button((isCustomRule ? "✓ Custom: \(item.rule.label)…" : "    Custom interval…")) {
                    editEvery = item.repeatMode == .every ? item.every : 2
                    editUnit = item.repeatMode == .every ? item.unit : .day
                    editingRule = true
                }
            }
            if item.isRepeating && !item.history.isEmpty {
                Button("Undo Last Check-in") { store.undoCheckIn(item.id) }
            }
            Divider()
            Button("Delete") { store.delete(item.id) }
        }
    }

    /// Due date `days` from today, keeping the task's time if it had one.
    private func quickDue(_ days: Int) -> String {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date())) ?? Date()
        if let info = item.dueInfo, info.hasTime {
            let hm = cal.dateComponents([.hour, .minute], from: info.date)
            if let d = cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: day) {
                return DueDate.encode(d, hasTime: true)
            }
        }
        return DueDate.encode(day, hasTime: false)
    }

    /// Inline "Every [n] [Days | Weeks | Months]" editor
    private var ruleEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Every")
                    .font(pal.font(0.85))
                    .foregroundColor(pal.secondary)
                Text("\(editEvery)")
                    .font(pal.font(0.9, bold: true))
                    .foregroundColor(pal.primary)
                    .frame(minWidth: 22)
                Stepper("", value: $editEvery, in: 1...365)
                    .labelsHidden()
                Picker("", selection: $editUnit) {
                    ForEach(RepeatUnit.allCases, id: \.self) { u in
                        Text(u.short).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { editingRule = false }
                    .buttonStyle(.plain)
                    .font(pal.font(0.85))
                    .foregroundColor(pal.secondary)
                Button("Set") {
                    store.setRepeat(item.id, RepeatRule(mode: .every, every: editEvery, unit: editUnit))
                    editingRule = false
                }
                .buttonStyle(.plain)
                .font(pal.font(0.85, bold: true))
                .foregroundColor(pal.accent)
            }
        }
        .padding(.leading, 24)
        .padding(.bottom, 2)
    }
}

// MARK: - Due date editor (inline calendar)

struct DueEditor: View {
    let pal: Palette
    let initial: String?
    let onSet: (String?) -> Void      // nil = remove the due date
    let onCancel: () -> Void
    @State private var date: Date
    @State private var withTime: Bool

    init(pal: Palette, initial: String?, onSet: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.pal = pal
        self.initial = initial
        self.onSet = onSet
        self.onCancel = onCancel
        let cal = Calendar.current
        let info = initial.flatMap { DueDate.decode($0) }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        let fallback = cal.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        _date = State(initialValue: info?.date ?? fallback)
        _withTime = State(initialValue: info?.hasTime ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                quick("Today", 0)
                quick("Tmr", 1)
                quick("+3d", 3)
                quick("+1w", 7)
            }
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack(spacing: 8) {
                Toggle(isOn: $withTime) {
                    Text("Time").font(pal.font(0.85)).foregroundColor(pal.primary)
                }
                .toggleStyle(.checkbox)
                if withTime {
                    DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field)
                        .labelsHidden()
                }
                Spacer()
            }
            HStack(spacing: 12) {
                if initial != nil {
                    Button("Remove") { onSet(nil) }
                        .buttonStyle(.plain)
                        .font(pal.font(0.85))
                        .foregroundColor(Urgency.overdue.color)
                }
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .font(pal.font(0.85))
                    .foregroundColor(pal.secondary)
                Button("Set") { onSet(DueDate.encode(date, hasTime: withTime)) }
                    .buttonStyle(.plain)
                    .font(pal.font(0.85, bold: true))
                    .foregroundColor(pal.accent)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9).fill(pal.surface.opacity(pal.dark ? 0.25 : 0.45)))
    }

    /// Jump to today + n days, keeping the chosen time.
    private func quick(_ title: String, _ days: Int) -> some View {
        Button {
            let cal = Calendar.current
            let day = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date())) ?? Date()
            let hm = cal.dateComponents([.hour, .minute], from: date)
            date = cal.date(bySettingHour: hm.hour ?? 18, minute: hm.minute ?? 0, second: 0, of: day) ?? day
        } label: {
            Text(title)
                .font(pal.font(0.8))
                .foregroundColor(pal.primary)
                .padding(.vertical, 3)
                .padding(.horizontal, 7)
                .background(Capsule().fill(pal.accent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drag to reorder

struct RowDropDelegate: DropDelegate {
    let target: TodoItem
    @Binding var dragging: String?
    let store: TodoStore

    // Reorder live as the dragged row passes over others.
    func dropEntered(info: DropInfo) {
        guard let id = dragging, id != target.id else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            store.move(id, onto: target.id)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - Settings window

struct SettingsView: View {
    @ObservedObject var s: AppSettings
    let glassAvailable: Bool
    private let families = NSFontManager.shared.availableFontFamilies.sorted()

    private func color(_ hex: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.hex })
    }

    private func sliderRow(_ title: String, _ value: Binding<Double>,
                           _ range: ClosedRange<Double>, step: Double,
                           _ format: @escaping (Double) -> String) -> some View {
        HStack {
            Text(title).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(format(value.wrappedValue))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    /// Small color chip button that sets the pinned text color.
    private func swatch(_ name: String, _ hex: String) -> some View {
        Button {
            s.pinnedTextHex = hex
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: hex))
                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    .frame(width: 14, height: 14)
                Text(name)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Capsule().stroke(s.pinnedTextHex == hex ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    /// "Remind me at" as a Date for the time picker (stored as minutes after midnight).
    private var remindTime: Binding<Date> {
        Binding(get: {
            let cal = Calendar.current
            return cal.date(byAdding: .minute, value: s.remindMinutes, to: cal.startOfDay(for: Date())) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            s.remindMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
        })
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Changes apply live — the panel stays open while this window is open.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Font", selection: $s.fontChoice) {
                            ForEach(FontChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if s.fontChoice == .custom {
                            Picker("Family", selection: $s.customFont) {
                                ForEach(families, id: \.self) { Text($0).tag($0) }
                            }
                        }
                        Picker("Weight", selection: $s.weight) {
                            ForEach(WeightChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        sliderRow("Size", $s.fontSize, 11...22, step: 0.5) { String(format: "%.1f pt", $0) }
                    }
                    .padding(8)
                } label: {
                    Label("Text", systemImage: "textformat")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        ColorPicker("Text color", selection: color($s.textHex), supportsOpacity: true)
                        ColorPicker("Text color when pinned", selection: color($s.pinnedTextHex), supportsOpacity: true)
                        HStack(spacing: 8) {
                            Text("Quick pick:").foregroundColor(.secondary)
                            swatch("Dark", "000000E6")
                            swatch("White", "FFFFFFFF")
                            Spacer()
                        }
                        .font(.callout)
                        ColorPicker("Accent (checkmarks, pin, +)", selection: color($s.accentHex), supportsOpacity: false)
                        ColorPicker("Background tint", selection: color($s.tintHex), supportsOpacity: false)
                        sliderRow("Tint strength", $s.tintStrength, 0...0.8, step: 0.01, percent)
                    }
                    .padding(8)
                } label: {
                    Label("Colors", systemImage: "paintpalette")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        sliderRow("Opacity", $s.bgOpacity, 0.2...1, step: 0.01, percent)
                        if glassAvailable {
                            Picker("Glass when focused", selection: $s.glass) {
                                ForEach(GlassChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Text("Liquid Glass needs macOS 26 or later.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Toggle("Bolder text when pinned", isOn: $s.pinnedBolder)
                        Toggle("Glow behind text when pinned (white for dark text, dark for white text)", isOn: $s.halo)
                    }
                    .padding(8)
                } label: {
                    Label("Background", systemImage: "square.on.square")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        sliderRow("Width", $s.width, 260...480, step: 10) { "\(Int($0))" }
                        sliderRow("Height", $s.height, 320...800, step: 10) { "\(Int($0))" }
                        sliderRow("Corner radius", $s.corner, 0...32, step: 1) { "\(Int($0))" }
                    }
                    .padding(8)
                } label: {
                    Label("Size", systemImage: "rectangle.portrait")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\"Due soon\" means").frame(width: 120, alignment: .leading)
                            Stepper(value: $s.soonDays, in: 0...14) {
                                Text(s.soonDays == 0 ? "only due today"
                                     : "within \(s.soonDays) day\(s.soonDays == 1 ? "" : "s")")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Toggle("Move due-soon tasks to the top", isOn: $s.dueOnTop)
                        Toggle("Glow on the screen edge when something is due today or overdue", isOn: $s.edgeGlow)
                        Toggle("Show the count on the menu bar icon", isOn: $s.menuBadge)
                        Toggle("Notifications", isOn: $s.notify)
                        if s.notify {
                            HStack {
                                Text("Remind me at").frame(width: 120, alignment: .leading)
                                DatePicker("", selection: remindTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Spacer()
                            }
                            Text("You'll get a reminder the day before and on the due day at this time, plus 1 hour before tasks with a set time.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                } label: {
                    Label("Due Dates & Reminders", systemImage: "bell.badge")
                }

                HStack {
                    Spacer()
                    Button("Reset to Defaults") { s.reset() }
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 720)
    }
}

// MARK: - Window plumbing

final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

func roundedMask(radius: CGFloat) -> NSImage {
    let r = max(radius, 0.5)
    let edge = r * 2 + 1
    let img = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
        NSColor.black.set()
        NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
        return true
    }
    img.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
    img.resizingMode = .stretch
    return img
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    let store = TodoStore()
    let state = PanelState()
    let settings = AppSettings()
    var panel: EdgePanel!
    var frostView: NSVisualEffectView!
    var glassView: NSView?          // Liquid Glass (macOS 26+), shown while pinned
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem!
    var expanded = false
    var outsideSince: Date?
    var mouseTimer: Timer?
    var cancellables = Set<AnyCancellable>()
    var lastCorner: Double = -1
    var holdOpenUntil: Date?        // keep the panel out for a moment after a notification click
    var reminderTimer: Timer?

    let peek: CGFloat = 6      // how many px stay visible at the screen edge
    let margin: CGFloat = 10

    var panelSize: NSSize { NSSize(width: settings.width, height: settings.height) }
    var screen: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    func expandedFrame() -> NSRect {
        let v = screen.visibleFrame
        return NSRect(x: v.maxX - panelSize.width - margin,
                      y: v.maxY - panelSize.height - margin,
                      width: panelSize.width, height: panelSize.height)
    }

    func collapsedFrame() -> NSRect {
        var f = expandedFrame()
        f.origin.x = screen.frame.maxX - peek
        return f
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = EdgePanel(contentRect: collapsedFrame(),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.delegate = self

        let bounds = NSRect(origin: .zero, size: panelSize)
        let container = NSView(frame: bounds)

        // Frosted background (default, while the panel auto-hides)
        let frost = NSVisualEffectView(frame: bounds)
        frost.material = .popover
        frost.blendingMode = .behindWindow
        frost.state = .active
        frost.autoresizingMask = [.width, .height]
        container.addSubview(frost)
        frostView = frost

        // Liquid Glass background (while pinned) — only when built against the macOS 26+ SDK
        #if GLASS
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.isHidden = true
            container.addSubview(glass)
            glassView = glass
        }
        #endif

        let host = ClickThroughHostingView(rootView: PanelView(store: store, state: state, settings: settings))
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)

        panel.contentView = container
        panel.orderFrontRegardless()

        state.openSettings = { [weak self] in self?.openSettings() }

        state.$pinned
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyMaterial() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)

        applySettings()
        setupStatusItem()
        setupReminders()

        let t = Timer(timeInterval: 0.05, target: self, selector: #selector(tick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        mouseTimer = t

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    /// Unpinned          → frosted (auto-hide mode)
    /// Pinned + focused  → Liquid Glass on top of frost (easy to read while you work in it)
    /// Pinned + unfocused→ clear glass drawn in SwiftUI, no blur, see-through
    func applyMaterial() {
        let focused = panel.isKeyWindow
        if state.panelKey != focused { state.panelKey = focused }

        // White text when pinned → dark frost & dark-tinted glass so it stays readable
        let darkLook = state.pinned && settings.pinnedTextIsLight
        frostView.material = darkLook ? .hudWindow : .popover
        panel.appearance = NSAppearance(named: darkLook ? .darkAqua : .aqua)

        if !state.pinned {
            frostView.isHidden = false
            glassView?.isHidden = true
        } else if focused {
            frostView.isHidden = false
            glassView?.isHidden = false
        } else {
            frostView.isHidden = true
            glassView?.isHidden = true
        }
        panel.invalidateShadow()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === panel { applyMaterial() }
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === panel { applyMaterial() }
    }

    func applySettings() {
        if settings.corner != lastCorner {
            frostView.maskImage = roundedMask(radius: CGFloat(settings.corner))
            lastCorner = settings.corner
        }
        frostView.alphaValue = CGFloat(settings.bgOpacity)

        #if GLASS
        if #available(macOS 26.0, *), let glass = glassView as? NSGlassEffectView {
            glass.cornerRadius = CGFloat(settings.corner)
            glass.style = (settings.glass == .clear) ? .clear : .regular
            glass.alphaValue = CGFloat(settings.bgOpacity)
        }
        #endif

        let target = expanded ? expandedFrame() : collapsedFrame()
        if panel.frame.size != target.size || panel.frame.origin != target.origin {
            panel.setFrame(target, display: true)
        }
        applyMaterial()
    }

    // MARK: Settings window

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.title = "EdgeTodo Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(s: settings, glassAvailable: glassView != nil))
            w.center()
            // Keep it clear of the panel on the right edge.
            var f = w.frame
            f.origin.x = max(screen.visibleFrame.minX + 40,
                             screen.visibleFrame.maxX - CGFloat(settings.width) - f.width - 60)
            w.setFrame(f, display: false)
            w.delegate = self
            settingsWindow = w
        }
        state.previewing = true
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            state.previewing = false
        }
    }

    // MARK: Menu bar

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "EdgeTodo")

        let menu = NSMenu()
        let pin = NSMenuItem(title: "Pin / Unpin Panel", action: #selector(togglePin), keyEquivalent: "")
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        let folder = NSMenuItem(title: "Open Data Folder", action: #selector(openFolder), keyEquivalent: "")
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        for item in [pin, prefs, folder, login] { item.target = self; menu.addItem(item) }
        if #available(macOS 13.0, *) {
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            login.isHidden = true
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit EdgeTodo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
    }

    // MARK: Due-date reminders

    /// Notifications need a real .app bundle (a bare binary would crash here).
    var canNotify: Bool { Bundle.main.bundleIdentifier != nil }

    func setupReminders() {
        if canNotify {
            UNUserNotificationCenter.current().delegate = self
            if settings.notify { requestNotificationPermission() }
        }
        // Reschedule whenever tasks or settings change (debounced)
        store.$todos.map { _ in () }
            .merge(with: settings.objectWillChange.map { _ in () })
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                if self.settings.notify { self.requestNotificationPermission() }
                self.rescheduleNotifications()
                self.updateBadge()
            }
            .store(in: &cancellables)
        // Time passing turns "due soon" into "due today" / "overdue"
        let t = Timer(timeInterval: 60, target: self, selector: #selector(minuteTick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        reminderTimer = t
        updateBadge()
        rescheduleNotifications()
    }

    @objc func minuteTick() { updateBadge() }

    private var askedPermission = false
    func requestNotificationPermission() {
        guard canNotify, !askedPermission else { return }
        askedPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Menu bar icon shows how many tasks are due today or overdue.
    func updateBadge() {
        let now = Date()
        let urgencies = store.todos.map { $0.urgency(now, soonDays: settings.soonDays) }
        let n = urgencies.filter { $0 >= .today }.count
        guard let button = statusItem?.button else { return }
        if settings.menuBadge && n > 0 {
            statusItem.length = NSStatusItem.variableLength
            let color: NSColor = urgencies.contains(.overdue) ? .systemRed : .systemOrange
            button.attributedTitle = NSAttributedString(string: " \(n)", attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            ])
            button.imagePosition = .imageLeft
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            statusItem.length = NSStatusItem.squareLength
        }
    }

    /// Schedules: day before (if "due soon" covers it), due day at the reminder time,
    /// and 1 hour before tasks that have a set time.
    func rescheduleNotifications() {
        guard canNotify else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard settings.notify else { return }

        let cal = Calendar.current
        let now = Date()
        let tf = DateFormatter()
        tf.locale = Locale(identifier: "en_US")
        tf.dateFormat = "h:mm a"
        var pending: [(Date, String, UNMutableNotificationContent)] = []

        for item in store.todos where item.status == .todo || item.status == .pending {
            guard let info = item.dueInfo, let deadline = item.dueDeadline else { continue }
            let day = cal.startOfDay(for: info.date)
            func at(_ d: Date) -> Date { cal.date(byAdding: .minute, value: settings.remindMinutes, to: d) ?? d }
            let time = info.hasTime ? " at \(tf.string(from: info.date))" : ""

            var fires: [(Date, String)] = []
            if settings.soonDays >= 1, let before = cal.date(byAdding: .day, value: -1, to: day) {
                fires.append((at(before), "Due tomorrow\(time)"))
            }
            fires.append((at(day), "Due today\(time)"))
            if info.hasTime { fires.append((info.date.addingTimeInterval(-3600), "Due in 1 hour")) }

            for (i, f) in fires.enumerated() where f.0 > now && f.0 < deadline {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.subtitle = "#\(item.category)"
                content.body = "⏰ " + f.1
                content.sound = .default
                pending.append((f.0, "\(item.id)-\(i)", content))
            }
        }

        // macOS keeps at most 64 pending notifications — schedule the soonest
        for (date, id, content) in pending.sorted(by: { $0.0 < $1.0 }).prefix(60) {
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    // Show banners even if EdgeTodo happens to be the active app
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Clicking a notification slides the panel out for a few seconds
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            self.holdOpenUntil = Date().addingTimeInterval(6)
            self.expand()
        }
        completionHandler()
    }

    // MARK: Hover logic

    @objc func tick() {
        let m = NSEvent.mouseLocation
        let exp = expandedFrame()

        if state.pinned || state.previewing || (holdOpenUntil.map { $0 > Date() } ?? false) {
            outsideSince = nil
            if !expanded { expand() }
            return
        }

        if !expanded {
            let hotEdge = NSRect(x: screen.frame.maxX - 3, y: exp.minY, width: 3, height: exp.height)
            if hotEdge.contains(m) || panel.frame.contains(m) { expand() }
        } else {
            if exp.insetBy(dx: -24, dy: -24).contains(m) {
                outsideSince = nil
            } else if let since = outsideSince {
                if Date().timeIntervalSince(since) > 0.5 { collapse() }
            } else {
                outsideSince = Date()
            }
        }
    }

    func expand() {
        guard !expanded else { return }
        expanded = true
        outsideSince = nil
        animate(to: expandedFrame())
    }

    func collapse() {
        guard expanded else { return }
        expanded = false
        outsideSince = nil
        if panel.isKeyWindow {
            // Give keyboard focus back to whatever app you were using.
            panel.makeFirstResponder(nil)
            panel.orderOut(nil)
            panel.setFrame(collapsedFrame(), display: false)
            panel.orderFrontRegardless()
        } else {
            animate(to: collapsedFrame())
        }
    }

    func animate(to f: NSRect) {
        let p = panel!
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrame(f, display: true)
        }
    }

    @objc func screensChanged() {
        panel.setFrame(expanded ? expandedFrame() : collapsedFrame(), display: true)
    }

    @objc func togglePin() {
        state.pinned.toggle()
    }

    @objc func openSettingsFromMenu() {
        openSettings()
    }

    @objc func openFolder() {
        NSWorkspace.shared.open(store.folderURL)
    }

    @objc func toggleLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                NSSound.beep()
            }
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}

@main
struct EdgeTodoMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
