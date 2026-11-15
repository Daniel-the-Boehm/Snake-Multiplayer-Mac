import AppKit
import Darwin
import Observation
import QuartzCore

enum Role: String {
    case solo, host, client, local
}

enum MPScreen {
    case menu, hostWait, join
}

enum Key: Equatable {
    case up, down, left, right, space, enter, esc, backspace, rshift, rctrl, kp0
    case char(String)

    init(_ e: NSEvent) {
        switch e.keyCode {
        case 126: self = .up
        case 125: self = .down
        case 123: self = .left
        case 124: self = .right
        case 49: self = .space
        case 36, 76: self = .enter
        case 53: self = .esc
        case 51: self = .backspace
        case 82: self = .kp0
        default: self = .char((e.charactersIgnoringModifiers ?? "").lowercased())
        }
    }

    var direction: Cell? {
        switch self {
        case .up, .char("w"): return Cell(0, -1)
        case .down, .char("s"): return Cell(0, 1)
        case .left, .char("a"): return Cell(-1, 0)
        case .right, .char("d"): return Cell(1, 0)
        default: return nil
        }
    }

    var isArrow: Bool { self == .up || self == .down || self == .left || self == .right }
    var isWASD: Bool { self == .char("w") || self == .char("a") || self == .char("s") || self == .char("d") }
    var isTeleport: Bool { self == .char("r") || self == .rshift || self == .rctrl || self == .kp0 }
}

struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double
    var total: Double
    var color: RGB
    var size: Double
}

struct EatFx {
    var cell: Cell
    var start: Double
    var dur: Double
}

struct Ring {
    var x: Double
    var y: Double
    var born: Double
}

final class SnakeAnim {
    var pts: [CGPoint] = []
    var face: Double
    var look: (Double, Double)
    var mouth = 0.0

    init(_ dir: Cell) {
        face = atan2(Double(dir.y), Double(dir.x))
        look = (Double(dir.x), Double(dir.y))
    }
}

enum Tone: Equatable {
    case text, muted, accent
}

struct CardLine: Equatable, Hashable {
    var text: String
    var size: Double
    var tone: Tone
}

enum CardAnchor: Equatable {
    case center, upper, idle, top
}

struct BoardCard: Equatable {
    var lines: [CardLine]
    var anchor: CardAnchor
}

struct HUDEntry: Equatable, Identifiable {
    var id: Int
    var isApple: Bool
    var style: String
    var text: String
    var alive: Bool
    var teleports: Int
}

struct HUD: Equatable {
    var solo = true
    var score = 0
    var best = 0
    var showTeleports = false
    var teleports = 0
    var entries: [HUDEntry] = []
    var timeLeft: Int?
    var info = ""
    var live = false
}

struct LobbyEntry: Equatable, Identifiable {
    var id: Int
    var name: String
    var style: String?
}

final class FrameDriver: NSObject {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func fire() {
        action()
    }
}

@Observable
final class AppModel {
    let cfg = Config()

    var settingsOpen = false
    var settingsSel = 0
    var settingsNote: String?
    var mpScreen: MPScreen?
    var mpMsg = ""
    var joinText = ""
    var foundHosts: [FoundHost] = []
    var lobby: [LobbyEntry] = []
    var pendingDrop: URL?
    var toast: String?
    var photoVer = 0
    var hud = HUD()
    var card: BoardCard?
    var dims = Cell(16, 16)
    var role: Role = .solo
    var paused = false
    var firstApple = 1
    var hostPort = NET_PORT
    var myIP = "127.0.0.1"

    @ObservationIgnored var game: Game
    @ObservationIgnored var photos: [String: CGImage] = [:]
    @ObservationIgnored var anims: [SnakeAnim] = []
    @ObservationIgnored var particles: [Particle] = []
    @ObservationIgnored var eatFx: [EatFx] = []
    @ObservationIgnored var rings: [Ring] = []
    @ObservationIgnored var shake = 0.0
    @ObservationIgnored var time = 0.0
    @ObservationIgnored var blinkLeft = 0.0
    @ObservationIgnored var blinkNext = 3.0
    @ObservationIgnored var localIdx = 0
    @ObservationIgnored var net: Link?
    @ObservationIgnored var peers: [Peer] = []
    @ObservationIgnored var server: Int32 = -1
    @ObservationIgnored var beacon: Int32 = -1
    @ObservationIgnored var disc: Int32 = -1
    @ObservationIgnored var pending: PendingConnection?
    @ObservationIgnored var found: [String: FoundHost] = [:]
    @ObservationIgnored var nextBeacon = 0.0
    @ObservationIgnored var lastRx = 0.0
    @ObservationIgnored var lastPing = 0.0
    @ObservationIgnored var lastCd = 0.0
    @ObservationIgnored var sentTick = -1
    @ObservationIgnored var sentState: GameState?
    @ObservationIgnored var roundNo = 0
    @ObservationIgnored var noteUntil = 0.0
    @ObservationIgnored var toastUntil = 0.0
    @ObservationIgnored private var driver: FrameDriver?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var lastStamp: CFTimeInterval = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        game = Game(cfg)
        loadSavedPhotos()
        resetAnims()
        dims = Cell(game.cols, game.rows)
    }

    // MARK: lifecycle

    func start() {
        guard driver == nil else { return }
        signal(SIGPIPE, SIG_IGN)
        lastStamp = CACurrentMediaTime()
        let d = FrameDriver { [weak self] in self?.frameTick() }
        driver = d
        if let screen = NSScreen.main {
            let l = screen.displayLink(target: d, selector: #selector(FrameDriver.fire))
            l.add(to: .main, forMode: .common)
            link = l
        } else {
            let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.frameTick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] e in
            guard let self else { return e }
            return self.handle(e)
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.focusLost()
        })
        observers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.closeNet()
        })
    }

    private func frameTick() {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastStamp, 0), 0.05)
        lastStamp = now
        update(dt)
    }

    private func focusLost() {
        game.held.removeAll()
        if (role == .solo || role == .local) && game.state == .running {
            paused = true
        }
    }

    // MARK: keyboard

    private func handle(_ e: NSEvent) -> NSEvent? {
        if e.modifierFlags.contains(.command) { return e }
        switch e.type {
        case .flagsChanged:
            if e.keyCode == 60 && e.modifierFlags.contains(.shift) { onKey(.rshift) }
            if e.keyCode == 62 && e.modifierFlags.contains(.control) { onKey(.rctrl) }
            return e
        case .keyDown:
            let key = Key(e)
            if mpScreen == .join && pendingDrop == nil && key != .esc { return e }
            if e.isARepeat && !settingsOpen { return nil }
            onKey(key)
            return nil
        case .keyUp:
            if mpScreen == .join { return e }
            onKeyUp(Key(e))
            return nil
        default:
            return e
        }
    }

    func onKey(_ k: Key) {
        let g = game
        if pendingDrop != nil {
            switch k {
            case .char("b"): chooseDrop("bg_photo")
            case .char("h"): chooseDrop("head_photo")
            case .char("f"): chooseDrop("fruit_photo")
            case .esc: pendingDrop = nil
            default: break
            }
            return
        }
        if mpScreen != nil {
            mpKey(k)
            return
        }
        if settingsOpen {
            panelKey(k)
            return
        }
        if k == .esc {
            toggleSettings()
        } else if k == .char("m") {
            openMPMenu()
        } else if k == .char("p") {
            togglePause()
        } else if k.isTeleport && g.apple != nil && (k == .char("r") || role == .local) {
            doTeleport()
        } else if k == .char("r") || k == .backspace {
            if role != .host || g.state == .dead { restart() }
        } else if (k == .space || k == .enter) && g.state == .dead {
            restart()
        } else if let d = k.direction, !paused {
            steerLocal(d, k)
        }
    }

    func onKeyUp(_ k: Key) {
        guard let d = k.direction else { return }
        let g = game
        if role == .client {
            if g.apple != nil && g.appleSlot == localIdx { net?.send(["t": "rel", "d": d.json]) }
        } else if role == .local {
            if g.apple != nil, let slot = g.appleSlot {
                if slot == 0 ? k.isArrow : k.isWASD { g.release(d) }
            }
        } else if g.apple == nil || g.appleSlot == nil || g.appleSlot == localIdx {
            g.release(d)
        }
    }

    func menuRestart() {
        if mpScreen != nil || pendingDrop != nil { return }
        if role != .host || game.state == .dead { restart() }
    }

    func togglePause() {
        if (role == .solo || role == .local) && game.state == .running {
            paused.toggle()
        }
    }

    private func steerLocal(_ raw: Cell, _ k: Key) {
        switch role {
        case .client:
            net?.send(["t": "dir", "d": raw.json])
        case .local:
            game.steer(k.isArrow ? 0 : 1, raw)
        default:
            game.steer(localIdx, raw)
        }
    }

    private func doTeleport() {
        let g = game
        if g.apple == nil || paused { return }
        switch role {
        case .client:
            if g.appleSlot == localIdx { net?.send(["t": "tp"]) }
        case .host:
            if g.appleSlot == localIdx { g.teleport() }
        default:
            g.teleport()
        }
    }

    func restart() {
        if role == .client { return }
        if role == .host || role == .local {
            startRound()
            return
        }
        game.reset(players: 1)
        finishRestart()
    }

    private func finishRestart() {
        paused = false
        particles.removeAll()
        eatFx.removeAll()
        rings.removeAll()
        shake = 0
        resetAnims()
    }

    private func resetAnims() {
        anims = game.snakes.map { SnakeAnim($0.dir) }
        for (a, s) in zip(anims, game.snakes) { a.pts = snakePoints(s) }
    }

    // MARK: settings

    func toggleSettings() {
        if mpScreen != nil || pendingDrop != nil { return }
        settingsOpen.toggle()
    }

    private func panelKey(_ k: Key) {
        let n = OPTIONS.count
        switch k {
        case .esc, .enter: settingsOpen = false
        case .up, .char("w"): settingsSel = (settingsSel - 1 + n) % n
        case .down, .char("s"): settingsSel = (settingsSel + 1) % n
        case .left, .char("a"): change(settingsSel, -1)
        case .right, .char("d"): change(settingsSel, 1)
        default: break
        }
    }

    func change(_ i: Int, _ step: Int) {
        let key = OPTIONS[i].key
        if role == .client && LOCKED_FOR_CLIENT.contains(key) {
            settingsNote = "Only the host can change this setting."
            noteUntil = time + 2.5
            return
        }
        cfg.cycle(key, step)
        cfg.save()
        if key == "map" || key == "mode" {
            restart()
        } else if key == "apples" {
            game.fillFoods()
        }
    }

    func shownValue(_ key: String) -> String {
        if role == .client && LOCKED_FOR_CLIENT.contains(key) {
            return game.remoteRules[key] ?? cfg[key]
        }
        return cfg[key]
    }

    // MARK: photos

    private func loadSavedPhotos() {
        for kind in PHOTO_KEYS {
            photos[kind] = Photos.loadSaved(kind)
        }
        photoVer += 1
    }

    func chooseDrop(_ kind: String) {
        guard let url = pendingDrop else { return }
        pendingDrop = nil
        guard let raw = Photos.load(url), let img = Photos.prepare(kind, raw) else {
            showToast("Couldn't open that file. Try a PNG or JPG.")
            return
        }
        Photos.save(img, kind)
        photos[kind] = img
        photoVer += 1
        cfg.v[kind] = "On"
        cfg.save()
        showToast("\(PHOTO_LABELS[kind] ?? "Photo") set")
    }

    func showToast(_ text: String) {
        toast = text
        toastUntil = time + 2.8
    }

    func fruitPhotoOn() -> Bool {
        cfg["fruit_photo"] == "On" && photos["fruit_photo"] != nil
    }

    func headPhoto() -> CGImage? {
        cfg["head_photo"] == "On" ? photos["head_photo"] : nil
    }

    func bgPhoto() -> CGImage? {
        cfg["bg_photo"] == "On" ? photos["bg_photo"] : nil
    }

    // MARK: update

    func update(_ dt: Double) {
        time += dt
        netUpdate()
        let g = game
        let sim: Bool
        if role == .solo || role == .local {
            sim = !paused && !settingsOpen && pendingDrop == nil && mpScreen == nil
        } else {
            sim = true
        }
        g.update(dt, simulate: sim)
        netSendState()
        consumeEvents()
        if anims.count != g.snakes.count {
            anims = g.snakes.map { SnakeAnim($0.dir) }
        }
        for (a, s) in zip(anims, g.snakes) { a.pts = snakePoints(s) }
        animateHead(dt)

        let damp = exp(-3.0 * dt)
        for i in particles.indices {
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].vx *= damp
            particles[i].vy *= damp
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
        eatFx.removeAll { time - $0.start >= $0.dur }
        rings.removeAll { time - $0.born >= 0.4 }
        shake = max(0, shake - dt * 2.5)

        if settingsNote != nil && time >= noteUntil { settingsNote = nil }
        if toast != nil && time >= toastUntil { toast = nil }
        let d = Cell(g.cols, g.rows)
        if d != dims { dims = d }
        let h = makeHUD()
        if h != hud { hud = h }
        let c = makeCard()
        if c != card { card = c }
    }

    private func burst(_ x: Double, _ y: Double, _ color: RGB, _ n: Int) {
        for _ in 0..<n {
            let a = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 1.5...4.5)
            let life = Double.random(in: 0.35...0.7)
            particles.append(Particle(x: x, y: y, vx: cos(a) * sp, vy: sin(a) * sp, life: life, total: life,
                                      color: color, size: Double.random(in: 0.09...0.17)))
        }
    }

    private func consumeEvents() {
        let g = game
        let fruit = FRUIT_COLORS[cfg["fruit"]] ?? RGB(226, 60, 52)
        for e in g.events {
            let cx = Double(e.cell.x) + 0.5
            let cy = Double(e.cell.y) + 0.5
            switch e.kind {
            case "eat":
                burst(cx, cy, fruit, 14)
                eatFx.append(EatFx(cell: e.cell, start: time, dur: max(0.05, (1 - g.t) * g.interval())))
            case "die":
                burst(cx, cy, style(styleOf(e.idx)).body, 22)
                shake = 1
            case "reverse":
                burst(cx, cy, .white, 12)
            case "eaten":
                burst(cx, cy, fruit, 26)
                eatFx.append(EatFx(cell: e.cell, start: time, dur: max(0.05, (1 - g.t) * g.interval())))
                shake = 1
            case "poof":
                burst(cx, cy, .white, 10)
                rings.append(Ring(x: cx, y: cy, born: time))
            default:
                break
            }
        }
        g.events.removeAll()
    }

    func delta(_ dx: Double, _ dy: Double) -> (Double, Double) {
        if game.mode == "No Borders" {
            return (wrapStep(dx, game.cols), wrapStep(dy, game.rows))
        }
        return (dx, dy)
    }

    private func snakePoints(_ s: Snake) -> [CGPoint] {
        let g = game
        let t = g.t
        let w = g.cols
        let h = g.rows
        func slide(_ a: Cell, _ b: Cell) -> CGPoint {
            CGPoint(x: Double(a.x) + wrapStep(Double(b.x - a.x), w) * t + 0.5,
                    y: Double(a.y) + wrapStep(Double(b.y - a.y), h) * t + 0.5)
        }
        func attach(_ prev: CGPoint, _ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: prev.x + wrapStep(x - prev.x, w), y: prev.y + wrapStep(y - prev.y, h))
        }
        var pts = [slide(s.hFrom, s.hTo)]
        for c in s.pathCells {
            pts.append(attach(pts[pts.count - 1], Double(c.x) + 0.5, Double(c.y) + 0.5))
        }
        let tail = slide(s.tFrom, s.tTo)
        pts.append(attach(pts[pts.count - 1], tail.x, tail.y))
        return pts
    }

    private func animateHead(_ dt: Double) {
        let g = game
        let cells = g.targets() + eatFx.map(\.cell)
        for (a, s) in zip(anims, g.snakes) {
            guard let head = a.pts.first else { continue }
            let target = atan2(Double(s.dir.y), Double(s.dir.x))
            var diff = (target - a.face + .pi).truncatingRemainder(dividingBy: 2 * .pi)
            if diff < 0 { diff += 2 * .pi }
            diff -= .pi
            a.face += diff * (1 - exp(-dt * 18))

            var want = 0.0
            if s.alive && !cells.isEmpty {
                var best: (Double, Double, Double)?
                for c in cells {
                    let (dx, dy) = delta(Double(c.x) + 0.5 - head.x, Double(c.y) + 0.5 - head.y)
                    let d = hypot(dx, dy)
                    if best == nil || d < best!.0 { best = (d, dx, dy) }
                }
                if let b = best {
                    let (d, dx, dy) = b
                    let front = (dx * Double(s.dir.x) + dy * Double(s.dir.y)) / max(d, 1e-6)
                    if front > 0.55 && d < 3.6 { want = clamp((3.6 - d) / 2.4, 0, 1) }
                }
            }
            let rate = want > a.mouth ? 24.0 : 14.0
            a.mouth += (want - a.mouth) * (1 - exp(-dt * rate))

            var lx = Double(s.dir.x)
            var ly = Double(s.dir.y)
            if let q = s.queue.first {
                lx = lx * 0.6 + Double(q.x) * 0.9
                ly = ly * 0.6 + Double(q.y) * 0.9
            }
            let n = hypot(lx, ly) == 0 ? 1 : hypot(lx, ly)
            let k = 1 - exp(-dt * 14)
            a.look.0 += (lx / n - a.look.0) * k
            a.look.1 += (ly / n - a.look.1) * k
        }
        blinkNext -= dt
        if blinkNext <= 0 {
            blinkLeft = 0.13
            blinkNext = Double.random(in: 2.5...5.5)
        }
        blinkLeft = max(0, blinkLeft - dt)
    }

    // MARK: players

    func style(_ name: String) -> SnakeStyle {
        SNAKE_STYLES[name] ?? SNAKE_STYLES["Classic Blue"]!
    }

    func styleOf(_ i: Int) -> String {
        let g = game
        if let styles = g.styles, let slot = g.slotOfSnake(i), slot < styles.count {
            return styles[slot]
        }
        return cfg["snake"]
    }

    func label(_ slot: Int) -> String {
        if role == .local { return "P\(slot + 1)" }
        if slot == localIdx { return "You" }
        return game.players == 2 ? "Opponent" : "P\(slot + 1)"
    }

    func order() -> [Int] {
        let n = game.players
        if role == .local { return Array(0..<n) }
        return [localIdx] + (0..<n).filter { $0 != localIdx }
    }

    func photoSnake() -> Int? {
        let g = game
        if role == .local { return g.snakeOf(0) ?? g.snakeOf(1) }
        if g.apple != nil && g.players == 1 { return 0 }
        return g.snakeOf(localIdx)
    }

    // MARK: HUD and cards

    private func makeHUD() -> HUD {
        let g = game
        var h = HUD()
        h.live = role != .solo
        h.solo = g.players == 1
        if g.players == 1 {
            h.score = g.score
            h.best = max(cfg.best[g.mode] ?? 0, g.score)
            h.showTeleports = g.apple != nil
            h.teleports = g.teleports
        } else if g.apple != nil {
            for slot in order() where slot < g.slots.count {
                let sl = g.slots[slot]
                if sl.isApple {
                    h.entries.append(HUDEntry(id: slot, isApple: true, style: "", text: label(slot), alive: true,
                                              teleports: g.teleports))
                } else if sl.k < g.snakes.count {
                    let s = g.snakes[sl.k]
                    let text = s.alive ? "\(label(slot)) \(s.body.count)" : "\(label(slot)) out"
                    h.entries.append(HUDEntry(id: slot, isApple: false, style: styleOf(sl.k), text: text,
                                              alive: s.alive, teleports: 0))
                }
            }
            h.timeLeft = Int(ceil(g.timeLeft()))
        } else {
            for i in order() where i < g.snakes.count {
                let s = g.snakes[i]
                h.entries.append(HUDEntry(id: i, isApple: false, style: styleOf(i), text: "\(label(i)) \(s.score)",
                                          alive: s.alive, teleports: 0))
            }
        }
        let speed = g.rule("speed")
        var info = "\(g.mode)  ·  \(speed)"
        if g.mode == "Rush" {
            info += String(format: "  ·  x%.1f", (1 / g.interval()) / (SPEEDS[speed] ?? 9))
        }
        h.info = info
        return h
    }

    private func makeCard() -> BoardCard? {
        let g = game
        if settingsOpen || mpScreen != nil || pendingDrop != nil { return nil }
        switch g.state {
        case .countdown:
            var lines = [CardLine(text: "\(max(1, Int(ceil(g.cd))))", size: 72, tone: .text)]
            if g.apple != nil, let slot = g.appleSlot {
                if role == .local {
                    let keys = slot == 0 ? "arrow keys" : "WASD"
                    lines.append(CardLine(text: "P\(slot + 1) is the APPLE (\(keys), R teleports)", size: 18, tone: .text))
                    lines.append(CardLine(text: "\(Int(APPLE_TIME)) seconds to survive, otherwise a snake eats you", size: 15, tone: .muted))
                } else if slot == localIdx {
                    lines.append(CardLine(text: "You are the APPLE: run! Hold a key to move, R teleports", size: 18, tone: .text))
                    lines.append(CardLine(text: "Survive \(Int(APPLE_TIME)) seconds or make every snake crash", size: 15, tone: .muted))
                } else {
                    lines.append(CardLine(text: "You are a SNAKE: catch the apple!", size: 18, tone: .text))
                    lines.append(CardLine(text: "The first snake to eat it wins. Time limit \(Int(APPLE_TIME))s", size: 15, tone: .muted))
                }
            } else if role == .local {
                lines.append(CardLine(text: "P1: arrow keys      P2: WASD", size: 18, tone: .text))
                lines.append(CardLine(text: "Last snake alive wins", size: 15, tone: .muted))
            } else {
                lines.append(CardLine(text: "Get ready: \(g.players) snakes start together", size: 16, tone: .muted))
            }
            return BoardCard(lines: lines, anchor: g.apple != nil ? .upper : .center)
        case .idle:
            if g.apple != nil {
                return BoardCard(lines: [
                    CardLine(text: "You are the apple! Hold an arrow key or WASD to run", size: 22, tone: .text),
                    CardLine(text: "R teleports you (3x)    Backspace restarts    P pause    Esc settings", size: 15, tone: .muted),
                ], anchor: .idle)
            }
            return BoardCard(lines: [
                CardLine(text: "Press an arrow key or WASD to start", size: 22, tone: .text),
                CardLine(text: "P pause    R restart    M multiplayer    Esc settings", size: 15, tone: .muted),
            ], anchor: .idle)
        default:
            break
        }
        if paused {
            return BoardCard(lines: [CardLine(text: "Paused", size: 38, tone: .text),
                                     CardLine(text: "Press P to resume", size: 18, tone: .muted)], anchor: .center)
        }
        if g.state == .dead && g.clock - g.deadAt > 0.45 {
            var lines: [CardLine] = []
            if g.players == 1 {
                let best = max(cfg.best[g.mode] ?? 0, g.score)
                let title = g.apple != nil ? (g.win ? "You trapped the snake!" : "You got eaten!")
                    : (g.win ? "You win!" : "Game over")
                lines = [CardLine(text: title, size: 40, tone: .text),
                         CardLine(text: "Score \(g.score)     Best \(best)", size: 22, tone: .accent)]
                if g.newBest { lines.append(CardLine(text: "New high score!", size: 18, tone: .accent)) }
                lines.append(CardLine(text: "Press Space or Enter to play again", size: 16, tone: .muted))
            } else {
                let title: String
                if g.winner == -1 || g.winner == nil {
                    title = "Draw"
                } else if role == .local {
                    title = "\(label(g.winner!)) wins!"
                } else if g.winner == localIdx {
                    title = "You win!"
                } else {
                    title = g.players == 2 ? "You lose" : "Player \(g.winner! + 1) wins"
                }
                let again = (role == .host || role == .local) ? "Press Space or Enter for the next round"
                    : "Waiting for the host to start the next round..."
                if g.apple != nil {
                    let why = ["eaten": "The apple got eaten", "time": "The apple survived!",
                               "crashed": "Every snake crashed", "left": "A player left"][g.why] ?? ""
                    lines = [CardLine(text: title, size: 40, tone: .text), CardLine(text: why, size: 22, tone: .accent),
                             CardLine(text: "Apple this round: \(label(g.appleSlot ?? 0))  (roles rotate)", size: 16, tone: .muted),
                             CardLine(text: again, size: 16, tone: .muted)]
                } else {
                    let scores = order().filter { $0 < g.snakes.count }
                        .map { "\(label($0)) \(g.snakes[$0].score)" }.joined(separator: "   ")
                    lines = [CardLine(text: title, size: 40, tone: .text),
                             CardLine(text: scores, size: g.players == 2 ? 22 : 19, tone: .accent),
                             CardLine(text: again, size: 16, tone: .muted)]
                }
            }
            return BoardCard(lines: lines, anchor: .center)
        }
        if g.state == .running && g.players > 1 && role != .local {
            if let mine = g.snakeOf(localIdx), mine < g.snakes.count, !g.snakes[mine].alive {
                return BoardCard(lines: [CardLine(text: "You're out. Watching until the round ends.", size: 18, tone: .text)],
                                 anchor: .top)
            }
        }
        return nil
    }

    var boardDimmed: Bool {
        let g = game
        if settingsOpen || mpScreen != nil || pendingDrop != nil { return false }
        if g.state == .idle || g.state == .countdown { return false }
        return paused || (g.state == .dead && g.clock - g.deadAt > 0.45)
    }

    // MARK: multiplayer menus

    func openMPMenu() {
        settingsOpen = false
        mpMsg = ""
        mpScreen = .menu
    }

    private func mpKey(_ k: Key) {
        guard let scr = mpScreen else { return }
        if k == .esc {
            if scr == .menu {
                mpScreen = nil
            } else {
                closeNet()
                mpScreen = .menu
            }
            return
        }
        switch scr {
        case .menu:
            guard role == .solo else { return }
            if k == .char("h") { beginHosting() }
            if k == .char("j") { beginJoin() }
            if k == .char("l") { startLocal() }
        case .hostWait:
            if k == .enter || k == .space { startMatch() }
            if k == .char("a") && cfg["mode"] == "Apple" { cycleFirstApple() }
        case .join:
            break
        }
    }

    func cycleFirstApple() {
        firstApple = (firstApple + 1) % (1 + peers.filter(\.ready).count)
    }

    func closeMPScreen() {
        mpScreen = nil
    }

    func backToMenu() {
        closeNet()
        mpScreen = .menu
    }

    func connectFound(_ host: FoundHost) {
        joinText = host.ip
        connectTo("\(host.ip):\(host.port)")
    }

    // MARK: networking

    func beginHosting() {
        closeLobby()
        let srv = socket(AF_INET, SOCK_STREAM, 0)
        guard srv >= 0 else {
            mpMsg = "Couldn't start hosting: no socket"
            return
        }
        Sock.setOption(srv, SOL_SOCKET, SO_REUSEADDR)
        var bound: Int?
        for port in NET_PORT..<(NET_PORT + 10) {
            guard let a = Sock.address("", port) else { continue }
            if Sock.withSockaddr(a, { Darwin.bind(srv, $0, $1) }) == 0 {
                bound = port
                break
            }
        }
        guard let port = bound, Darwin.listen(srv, Int32(MAX_PLAYERS)) == 0 else {
            Darwin.close(srv)
            mpMsg = "Couldn't start hosting: no free port"
            return
        }
        Sock.nonBlocking(srv)
        let b = socket(AF_INET, SOCK_DGRAM, 0)
        if b >= 0 {
            Sock.setOption(b, SOL_SOCKET, SO_BROADCAST)
            Sock.nonBlocking(b)
        }
        server = srv
        beacon = b
        hostPort = port
        myIP = Sock.localIP()
        nextBeacon = 0
        refreshLobby()
        mpScreen = .hostWait
    }

    func beginJoin() {
        closeLobby()
        let d = socket(AF_INET, SOCK_DGRAM, 0)
        if d >= 0 {
            Sock.setOption(d, SOL_SOCKET, SO_REUSEADDR)
            Sock.setOption(d, SOL_SOCKET, SO_REUSEPORT)
            if let a = Sock.address("", DISCOVERY_PORT), Sock.withSockaddr(a, { Darwin.bind(d, $0, $1) }) == 0 {
                Sock.nonBlocking(d)
                disc = d
            } else {
                Darwin.close(d)
            }
        }
        mpScreen = .join
    }

    func connectTo(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            mpMsg = "Type the host's IP address first."
            return
        }
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        let host = parts[0]
        let port = parts.count > 1 ? Int(parts[1]) : NET_PORT
        guard let port, let addr = Sock.address(host, port) else {
            mpMsg = "That address doesn't look right."
            return
        }
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            mpMsg = "That address doesn't look right."
            return
        }
        Sock.nonBlocking(fd)
        Sock.setOption(fd, SOL_SOCKET, SO_NOSIGPIPE)
        let r = Sock.withSockaddr(addr) { Darwin.connect(fd, $0, $1) }
        if r != 0 && errno != EINPROGRESS {
            Darwin.close(fd)
            mpMsg = "Couldn't connect. Same Wi-Fi? Is the host waiting?"
            return
        }
        if let p = pending { Darwin.close(p.fd) }
        pending = PendingConnection(fd: fd, deadline: time + 6)
        mpMsg = "Connecting to \(host)..."
    }

    private func closeListeners() {
        for fd in [server, beacon, disc] where fd >= 0 {
            Darwin.close(fd)
        }
        server = -1
        beacon = -1
        disc = -1
        if let p = pending {
            Darwin.close(p.fd)
            pending = nil
        }
        found = [:]
        if !foundHosts.isEmpty { foundHosts = [] }
    }

    private func closeLobby() {
        closeListeners()
        if role != .host {
            for p in peers {
                p.net.send(["t": "bye"])
                p.net.close()
            }
            peers = []
        }
        mpMsg = ""
        refreshLobby()
    }

    func closeNet() {
        if let n = net {
            n.send(["t": "bye"])
            n.close()
        }
        for p in peers {
            p.net.send(["t": "bye"])
            p.net.close()
        }
        net = nil
        peers = []
        closeListeners()
        mpMsg = ""
        refreshLobby()
    }

    func leaveMultiplayer(_ message: String? = nil) {
        closeNet()
        role = .solo
        localIdx = 0
        mpScreen = nil
        roundNo = 0
        game = Game(cfg)
        finishRestart()
        if let message { showToast(message) }
    }

    private func sendLobby() {
        let ready = peers.filter(\.ready)
        for (i, p) in ready.enumerated() {
            p.net.send(["t": "lobby", "you": i + 1, "count": ready.count + 1])
        }
        refreshLobby()
    }

    func lobbyStyles() -> [String] {
        var taken = [cfg["snake"]]
        for p in peers where p.ready {
            var want = p.style ?? ""
            if SNAKE_STYLES[want] == nil || taken.contains(want) {
                want = STYLE_NAMES.first { !taken.contains($0) } ?? STYLE_NAMES[0]
            }
            taken.append(want)
        }
        return taken
    }

    private func refreshLobby() {
        let styles = lobbyStyles()
        var entries: [LobbyEntry] = []
        for i in 0..<MAX_PLAYERS {
            let taken = i < styles.count
            let name = i == 0 ? "Player 1 (you, host)" : (taken ? "Player \(i + 1) joined" : "waiting...")
            entries.append(LobbyEntry(id: i, name: name, style: taken ? styles[i] : nil))
        }
        if entries != lobby { lobby = entries }
    }

    func startMatch() {
        let ready = peers.filter(\.ready)
        if ready.isEmpty {
            mpMsg = "Waiting for at least one more player."
            return
        }
        for p in peers where !p.ready { p.net.close() }
        peers = ready
        closeListeners()
        for (p, s) in zip(peers, lobbyStyles().dropFirst()) { p.style = s }
        role = .host
        localIdx = 0
        mpScreen = nil
        settingsOpen = false
        startRound()
    }

    private func dropPeer(_ peer: Peer) {
        guard let i = peers.firstIndex(where: { $0 === peer }) else { return }
        peer.net.close()
        peers.remove(at: i)
        if role == .host {
            game.dropPlayer(peer.idx)
            if peers.isEmpty {
                leaveMultiplayer("Everyone else left the game")
            } else {
                showToast("Player \(peer.idx + 1) left")
            }
        } else {
            sendLobby()
        }
    }

    func startLocal() {
        closeNet()
        let mine = cfg["snake"]
        role = .local
        localIdx = 0
        mpScreen = nil
        settingsOpen = false
        game = Game(cfg)
        game.styles = [mine, STYLE_NAMES.first { $0 != mine } ?? STYLE_NAMES[1]]
        roundNo = 0
        startRound()
    }

    private func startRound() {
        let g = game
        let local = role == .local
        let n: Int
        if local {
            n = 2
        } else {
            peers = peers.filter { !$0.net.closed }
            if peers.isEmpty {
                leaveMultiplayer("Everyone else left the game")
                return
            }
            for (i, p) in peers.enumerated() { p.idx = i + 1 }
            n = peers.count + 1
            g.styles = [cfg["snake"]] + peers.map { $0.style ?? STYLE_NAMES[0] }
        }
        var appleSlot: Int?
        if cfg["mode"] == "Apple" { appleSlot = (firstApple + roundNo) % n }
        roundNo += 1
        g.reset(players: n, countdown: 3, appleSlot: appleSlot)
        if !local {
            let rules: [String: Any] = ["map": cfg["map"], "mode": cfg["mode"], "apples": cfg.apples, "speed": cfg["speed"]]
            for p in peers {
                p.net.send(["t": "reset", "you": p.idx, "players": n, "styles": g.styles ?? [],
                            "rules": rules, "apple_slot": g.appleSlot.map { $0 as Any } ?? NSNull()])
            }
            sentTick = -1
            sentState = nil
        }
        finishRestart()
    }

    private func onReset(_ m: [String: Any]) {
        if role != .client {
            role = .client
            game = Game(cfg, remote: true)
            mpScreen = nil
            settingsOpen = false
            closeListeners()
        }
        if let you = (m["you"] as? NSNumber)?.intValue { localIdx = you }
        let g = game
        if let rules = m["rules"] as? [String: Any] {
            var r: [String: String] = [:]
            for (k, v) in rules {
                if let s = v as? String {
                    r[k] = s
                } else if let num = v as? NSNumber {
                    r[k] = num.stringValue
                }
            }
            g.remoteRules = r
        }
        g.styles = (m["styles"] as? [Any])?.compactMap { $0 as? String }
        let players = (m["players"] as? NSNumber)?.intValue ?? 2
        g.reset(players: players, countdown: 3, appleSlot: (m["apple_slot"] as? NSNumber)?.intValue)
        finishRestart()
    }

    private func onNetMessage(_ m: [String: Any]) {
        switch m["t"] as? String ?? "" {
        case "bye":
            leaveMultiplayer("The host ended the game")
        case "full":
            closeNet()
            beginJoin()
            mpMsg = "That game is full (\(MAX_PLAYERS) players max)."
        case "lobby":
            let count = (m["count"] as? NSNumber)?.intValue ?? 2
            mpMsg = "Connected: \(count)/\(MAX_PLAYERS) players. Waiting for the host to start..."
        case "reset":
            onReset(m)
        case "cd":
            if role == .client, let v = (m["v"] as? NSNumber)?.doubleValue { game.cd = v }
        case "state":
            if role == .client { game.applySnapshot(m) }
        default:
            break
        }
    }

    private func onPeerMessage(_ peer: Peer, _ m: [String: Any]) {
        let kind = m["t"] as? String ?? ""
        let g = game
        if kind == "hello" && !peer.ready {
            peer.style = m["style"] as? String
            peer.ready = true
            sendLobby()
        } else if role != .host || peer.idx <= 0 {
            if kind == "bye" { dropPeer(peer) }
        } else if kind == "dir" {
            if let d = Cell.from(m["d"]), DIRS.contains(d) { g.steer(peer.idx, d) }
        } else if kind == "rel" {
            if g.apple != nil && g.appleSlot == peer.idx, let d = Cell.from(m["d"]) { g.release(d) }
        } else if kind == "tp" {
            if g.apple != nil && g.appleSlot == peer.idx { g.teleport() }
        } else if kind == "bye" {
            dropPeer(peer)
        }
    }

    private func netUpdate() {
        if server >= 0 {
            if beacon >= 0 && time >= nextBeacon {
                nextBeacon = time + 1
                let count = 1 + peers.filter(\.ready).count
                let msg = Array("SNAKE\(NET_VERSION):\(hostPort):\(count)".utf8)
                if let a = Sock.address("255.255.255.255", DISCOVERY_PORT) {
                    let fd = beacon
                    _ = Sock.withSockaddr(a) { sa, len in
                        msg.withUnsafeBytes { Darwin.sendto(fd, $0.baseAddress, $0.count, 0, sa, len) }
                    }
                }
            }
            for _ in 0..<4 {
                let c = Darwin.accept(server, nil, nil)
                if c < 0 { break }
                let link = Link(fd: c)
                if peers.count >= MAX_PLAYERS - 1 {
                    link.send(["t": "full"])
                    link.close()
                } else {
                    peers.append(Peer(net: link, rx: time))
                }
            }
        }

        if disc >= 0 {
            var changed = false
            for _ in 0..<8 {
                var buf = [UInt8](repeating: 0, count: 256)
                var from = sockaddr_in()
                var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                let fd = disc
                let n = withUnsafeMutablePointer(to: &from) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        buf.withUnsafeMutableBytes { Darwin.recvfrom(fd, $0.baseAddress, $0.count, 0, sa, &len) }
                    }
                }
                if n <= 0 { break }
                let text = String(decoding: buf[0..<n], as: UTF8.self)
                guard text.hasPrefix("SNAKE\(NET_VERSION):") else { continue }
                let parts = text.split(separator: ":")
                guard parts.count >= 2, let port = Int(parts[1]) else { continue }
                let count = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
                let ip = Sock.ipString(from)
                found[ip] = FoundHost(ip: ip, port: port, seen: time, count: count)
                changed = true
            }
            let before = found.count
            found = found.filter { time - $0.value.seen < 4 }
            if changed || before != found.count {
                let list = found.values.sorted { $0.ip < $1.ip }
                let simplified = list.map { FoundHost(ip: $0.ip, port: $0.port, seen: 0, count: $0.count) }
                if simplified != foundHosts { foundHosts = simplified }
            }
        }

        if let pc = pending {
            var p = pollfd(fd: pc.fd, events: Int16(POLLOUT), revents: 0)
            let r = Darwin.poll(&p, 1, 0)
            var err: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(pc.fd, SOL_SOCKET, SO_ERROR, &err, &len)
            let failed = r < 0 || (p.revents & Int16(POLLERR | POLLHUP | POLLNVAL)) != 0
            let writable = (p.revents & Int16(POLLOUT)) != 0
            if failed || (writable && err != 0) {
                Darwin.close(pc.fd)
                pending = nil
                mpMsg = "Couldn't connect. Same Wi-Fi? Is the host waiting?"
            } else if writable {
                pending = nil
                closeLobby()
                let link = Link(fd: pc.fd)
                net = link
                lastRx = time
                lastPing = time
                link.send(["t": "hello", "v": NET_VERSION, "style": cfg["snake"]])
                mpMsg = "Connected. Waiting for the host to start..."
            } else if time > pc.deadline {
                Darwin.close(pc.fd)
                pending = nil
                mpMsg = "Timed out. Check the address and the Wi-Fi."
            }
        }

        for peer in peers {
            for m in peer.net.receive() {
                peer.rx = time
                onPeerMessage(peer, m)
                if !peers.contains(where: { $0 === peer }) { break }
            }
            if peers.contains(where: { $0 === peer }) && (peer.net.closed || time - peer.rx > 6) {
                dropPeer(peer)
            }
        }
        if !peers.isEmpty && time - lastPing > 1 {
            lastPing = time
            for p in peers { p.net.send(["t": "ping"]) }
        }

        if let link = net {
            for m in link.receive() {
                lastRx = time
                onNetMessage(m)
                if net == nil { return }
            }
            if link.closed {
                leaveMultiplayer("Disconnected from the host")
            } else if time - lastRx > 6 {
                leaveMultiplayer("Connection lost")
            } else if time - lastPing > 1 {
                lastPing = time
                link.send(["t": "ping"])
            }
        }
    }

    private func netSendState() {
        guard role == .host, !peers.isEmpty else { return }
        let g = game
        if g.tickNo != sentTick || g.state != sentState {
            let snap = g.snapshot()
            for p in peers { p.net.send(snap) }
            sentTick = g.tickNo
            sentState = g.state
        }
        if g.state == .countdown && time - lastCd >= 0.1 {
            lastCd = time
            for p in peers { p.net.send(["t": "cd", "v": g.cd]) }
        }
    }
}
