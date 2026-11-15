import SwiftUI

struct RGB: Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    var color: Color { Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1) }

    func color(_ alpha: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }

    func mix(_ o: RGB, _ t: Double) -> RGB {
        RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }

    static let white = RGB(255, 255, 255)
    static let black = RGB(0, 0, 0)
}

struct Theme {
    let window: RGB
    let window2: RGB
    let header: RGB
    let boardA: RGB
    let boardB: RGB
    let frame: RGB
    let text: RGB
    let muted: RGB
    let panel: RGB
    let accent: RGB
    let wall: RGB
    let wallHi: RGB
    let wallLo: RGB
}

struct SnakeStyle {
    let body: RGB
    let head: RGB
    let outline: RGB
    let shine: RGB?
    let seam: RGB?
    let radius: Double
}

struct OptionDef {
    let key: String
    let label: String
    let values: [String]
}

let NET_PORT = 55055
let DISCOVERY_PORT = 55056
let NET_VERSION = 1
let MAX_PLAYERS = 4
let CORPSE_TIME = 1.2
let APPLE_SNAKE_PAUSE = 7
let APPLE_GROW_TICKS = 24
let APPLE_MISTAKE = 0.10
let APPLE_WIN_BONUS = 10
let APPLE_TELEPORTS = 3
let APPLE_TIME = 60.0
let TELEPORT_MIN_DIST = 8
let TWIN_INVERTS_CONTROLS = false
let LOCKED_FOR_CLIENT: Set<String> = ["map", "mode", "speed", "apples"]

let MODES = ["Classic", "No Borders", "Wall", "Twin", "Mirror", "Rush", "Apple"]
let MODE_INFO: [String: String] = [
    "Classic": "Solid borders. Hit a wall or yourself and it's over.",
    "No Borders": "The edges wrap around: leave on one side, appear on the other.",
    "Wall": "Every apple turns the end of your tail into a permanent wall.",
    "Twin": "Eat an apple and head and tail swap, so you slither the other way.",
    "Mirror": "Left and right are swapped. Good luck.",
    "Rush": "The more you eat, the faster you go.",
    "Apple": "You are the apple: hold a key to run, R teleports (3x). Solo: an AI snake hunts you. With friends: they are the snakes, catch the apple or survive 60s.",
]

let SPEED_NAMES = ["Slow", "Normal", "Fast", "Turbo"]
let SPEEDS: [String: Double] = ["Slow": 6, "Normal": 9, "Fast": 12, "Turbo": 16]
let MAP_NAMES = ["Small", "Medium", "Large", "Huge"]
let MAP_SIZES: [String: (Int, Int)] = ["Small": (12, 12), "Medium": (16, 16), "Large": (24, 24), "Huge": (32, 32)]
let APPLE_COUNTS = [1, 2, 3, 4, 5, 10, 15, 25, 40, 144]
let FRUITS = ["Apple", "Cherry", "Orange", "Lemon", "Grapes"]
let FRUIT_COLORS: [String: RGB] = [
    "Apple": RGB(226, 60, 52), "Cherry": RGB(190, 24, 50), "Orange": RGB(255, 152, 32),
    "Lemon": RGB(250, 222, 64), "Grapes": RGB(132, 66, 190),
]

let THEME_NAMES = ["Classic", "Retro Dark", "Ocean Blue", "Sunset Neon"]
let THEMES: [String: Theme] = [
    "Classic": Theme(
        window: RGB(62, 99, 36), window2: RGB(62, 99, 36), header: RGB(74, 117, 44),
        boardA: RGB(170, 215, 81), boardB: RGB(162, 209, 73), frame: RGB(87, 138, 52),
        text: RGB(255, 255, 255), muted: RGB(214, 235, 178), panel: RGB(58, 94, 33), accent: RGB(255, 214, 79),
        wall: RGB(122, 104, 82), wallHi: RGB(168, 146, 116), wallLo: RGB(84, 70, 54)),
    "Retro Dark": Theme(
        window: RGB(12, 14, 20), window2: RGB(12, 14, 20), header: RGB(20, 24, 34),
        boardA: RGB(27, 33, 45), boardB: RGB(22, 27, 38), frame: RGB(52, 211, 120),
        text: RGB(214, 255, 224), muted: RGB(120, 168, 142), panel: RGB(24, 30, 42), accent: RGB(52, 211, 120),
        wall: RGB(96, 106, 124), wallHi: RGB(146, 158, 178), wallLo: RGB(56, 62, 76)),
    "Ocean Blue": Theme(
        window: RGB(10, 62, 104), window2: RGB(4, 28, 60), header: RGB(12, 70, 118),
        boardA: RGB(44, 150, 204), boardB: RGB(38, 140, 194), frame: RGB(104, 196, 240),
        text: RGB(240, 250, 255), muted: RGB(170, 215, 240), panel: RGB(10, 60, 104), accent: RGB(255, 196, 77),
        wall: RGB(22, 62, 100), wallHi: RGB(58, 110, 156), wallLo: RGB(10, 36, 62)),
    "Sunset Neon": Theme(
        window: RGB(24, 6, 48), window2: RGB(120, 30, 92), header: RGB(36, 11, 60),
        boardA: RGB(66, 22, 96), boardB: RGB(56, 17, 84), frame: RGB(255, 74, 176),
        text: RGB(255, 226, 245), muted: RGB(214, 150, 220), panel: RGB(34, 12, 56), accent: RGB(255, 150, 60),
        wall: RGB(255, 116, 74), wallHi: RGB(255, 178, 120), wallLo: RGB(196, 62, 66)),
]

let STYLE_NAMES = ["Classic Blue", "Retro Green", "Neon Purple", "Sunset Orange"]
let SNAKE_STYLES: [String: SnakeStyle] = [
    "Classic Blue": SnakeStyle(body: RGB(66, 118, 244), head: RGB(74, 128, 250), outline: RGB(34, 74, 190),
                               shine: RGB(132, 176, 255), seam: nil, radius: 0.30),
    "Retro Green": SnakeStyle(body: RGB(76, 190, 72), head: RGB(92, 210, 86), outline: RGB(16, 70, 28),
                              shine: nil, seam: RGB(40, 126, 46), radius: 0.06),
    "Neon Purple": SnakeStyle(body: RGB(122, 64, 226), head: RGB(142, 82, 244), outline: RGB(236, 128, 255),
                              shine: RGB(176, 122, 255), seam: nil, radius: 0.34),
    "Sunset Orange": SnakeStyle(body: RGB(240, 138, 36), head: RGB(250, 160, 62), outline: RGB(150, 72, 8),
                                shine: RGB(255, 204, 124), seam: nil, radius: 0.30),
]

let PHOTO_KEYS = ["bg_photo", "head_photo", "fruit_photo"]
let PHOTO_FILES: [String: String] = ["bg_photo": "background.png", "head_photo": "head.png", "fruit_photo": "fruit.png"]
let PHOTO_LABELS: [String: String] = ["bg_photo": "Background photo", "head_photo": "Head photo", "fruit_photo": "Fruit photo"]

let OPTIONS: [OptionDef] = [
    OptionDef(key: "fruit", label: "Fruit Type", values: FRUITS),
    OptionDef(key: "apples", label: "Apple Count", values: APPLE_COUNTS.map(String.init)),
    OptionDef(key: "speed", label: "Speed", values: SPEED_NAMES),
    OptionDef(key: "map", label: "Map Size", values: MAP_NAMES),
    OptionDef(key: "mode", label: "Game Mode", values: MODES),
    OptionDef(key: "snake", label: "Snake Style", values: STYLE_NAMES),
    OptionDef(key: "theme", label: "Background Theme", values: THEME_NAMES),
    OptionDef(key: "bg_photo", label: "Background Photo", values: ["Off", "On"]),
    OptionDef(key: "head_photo", label: "Head Photo", values: ["Off", "On"]),
    OptionDef(key: "fruit_photo", label: "Fruit Photo", values: ["Off", "On"]),
]

func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    v < lo ? lo : (v > hi ? hi : v)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

func smoothstep(_ t: Double) -> Double {
    let x = clamp(t, 0, 1)
    return x * x * (3 - 2 * x)
}

func easeOutBack(_ t: Double) -> Double {
    let x = clamp(t, 0, 1)
    let c1 = 1.70158
    let c3 = 2.70158
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}

func wrapStep(_ d: Double, _ n: Int) -> Double {
    let nn = Double(n)
    return d - nn * floor(d / nn + 0.5)
}

func wrapStepInt(_ d: Int, _ n: Int) -> Int {
    d - n * Int(floor(Double(d) / Double(n) + 0.5))
}

func mpMapFor(_ base: String, _ players: Int) -> String {
    let i = MAP_NAMES.firstIndex(of: base) ?? 1
    return MAP_NAMES[min(i + max(0, players - 2), MAP_NAMES.count - 1)]
}

func dataDirectory() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    let dir = base.appendingPathComponent("Snake", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
