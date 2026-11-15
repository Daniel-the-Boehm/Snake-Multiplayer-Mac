import Foundation

struct Cell: Hashable {
    var x: Int
    var y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    var json: [Int] { [x, y] }

    static func from(_ any: Any?) -> Cell? {
        guard let a = any as? [Any], a.count >= 2,
              let x = (a[0] as? NSNumber)?.intValue, let y = (a[1] as? NSNumber)?.intValue else { return nil }
        return Cell(x, y)
    }

    static func list(_ any: Any?) -> [Cell] {
        guard let a = any as? [Any] else { return [] }
        return a.compactMap { Cell.from($0) }
    }
}

let DIRS = [Cell(1, 0), Cell(-1, 0), Cell(0, 1), Cell(0, -1)]

enum GameState: String {
    case idle, countdown, running, dead
}

struct Food {
    var cell: Cell
    var born: Double
}

struct GameEvent {
    var kind: String
    var cell: Cell
    var idx: Int
}

struct Slot {
    var isApple: Bool
    var k: Int
}

final class Snake {
    var body: [Cell]
    var dir: Cell
    var queue: [Cell] = []
    var alive = true
    var score = 0
    var twinFlip = false
    var grow = 0
    var gone = false
    var died = 0.0
    var pathCells: [Cell] = []
    var hFrom: Cell
    var hTo: Cell
    var tFrom: Cell
    var tTo: Cell

    init(_ head: Cell, _ direction: Cell, length: Int = 3) {
        body = (0..<length).map { Cell(head.x - direction.x * $0, head.y - direction.y * $0) }
        dir = direction
        hFrom = head
        hTo = head
        tFrom = head
        tTo = head
        still()
    }

    func still() {
        pathCells = body
        hFrom = body[0]
        hTo = body[0]
        tFrom = body[body.count - 1]
        tTo = body[body.count - 1]
    }

    func toDict() -> [String: Any] {
        [
            "body": body.map(\.json), "dir": dir.json, "path": pathCells.map(\.json),
            "hf": hFrom.json, "ht": hTo.json, "tf": tFrom.json, "tt": tTo.json,
            "alive": alive, "score": score, "q": queue.map(\.json), "gone": gone,
        ]
    }

    func load(_ d: [String: Any]) {
        let b = Cell.list(d["body"])
        if !b.isEmpty { body = b }
        pathCells = Cell.list(d["path"])
        if let c = Cell.from(d["dir"]) { dir = c }
        if let c = Cell.from(d["hf"]) { hFrom = c }
        if let c = Cell.from(d["ht"]) { hTo = c }
        if let c = Cell.from(d["tf"]) { tFrom = c }
        if let c = Cell.from(d["tt"]) { tTo = c }
        alive = (d["alive"] as? NSNumber)?.boolValue ?? alive
        score = (d["score"] as? NSNumber)?.intValue ?? score
        gone = (d["gone"] as? NSNumber)?.boolValue ?? false
        queue = Cell.list(d["q"])
    }
}

final class Game {
    let cfg: Config
    let remote: Bool
    var remoteRules: [String: String]
    var iv = 1.0 / 9.0
    var styles: [String]?

    var players = 1
    var cols = 16
    var rows = 16
    var mode = "Classic"
    var apple: Snake?
    var appleSlot: Int?
    var held: [Cell] = []
    var appleQueue: [Cell] = []
    var teleports = APPLE_TELEPORTS
    var why = ""
    var slots: [Slot] = []
    var snakes: [Snake] = []
    var walls: [Cell: Double] = [:]
    var foods: [Food] = []
    var state: GameState = .idle
    var cd = 3.0
    var winner: Int?
    var win = false
    var newBest = false
    var acc = 0.0
    var clock = 0.0
    var deadAt = 0.0
    var tickNo = 0
    var lastDying: [Int] = []
    var events: [GameEvent] = []

    init(_ cfg: Config, remote: Bool = false) {
        self.cfg = cfg
        self.remote = remote
        remoteRules = ["map": cfg["map"], "mode": cfg["mode"], "apples": cfg["apples"], "speed": cfg["speed"]]
        reset()
    }

    func rule(_ key: String) -> String {
        remote ? (remoteRules[key] ?? cfg[key]) : cfg[key]
    }

    var score: Int {
        if let a = apple { return a.score }
        return snakes[0].score
    }

    func targets() -> [Cell] {
        var cells = foods.map(\.cell)
        if let a = apple, a.alive { cells.append(a.body[0]) }
        return cells
    }

    func reset(players: Int = 1, countdown: Double = 3.0, appleSlot slotIn: Int? = nil) {
        self.players = players
        var name = rule("map")
        if players > 1 { name = mpMapFor(name, players) }
        let size = MAP_SIZES[name] ?? (16, 16)
        cols = size.0
        rows = size.1
        mode = rule("mode")
        apple = nil
        appleSlot = nil
        held = []
        appleQueue = []
        teleports = APPLE_TELEPORTS
        why = ""
        let starts: [(Cell, Cell)] = [
            (Cell(cols / 4, rows / 3), Cell(1, 0)),
            (Cell(cols - 1 - cols / 4, rows - 1 - rows / 3), Cell(-1, 0)),
            (Cell(cols - 1 - cols / 3, rows / 4), Cell(0, 1)),
            (Cell(cols / 3, rows - 1 - rows / 4), Cell(0, -1)),
        ]
        slots = (0..<players).map { Slot(isApple: false, k: $0) }
        if mode == "Apple" && players == 1 {
            snakes = [Snake(Cell(cols - 4, rows / 2), Cell(-1, 0))]
            apple = Snake(Cell(cols / 4, rows / 2), Cell(1, 0), length: 1)
        } else if mode == "Apple" {
            let aSlot = slotIn.map { (($0 % players) + players) % players } ?? (players - 1)
            appleSlot = aSlot
            let n = players - 1
            if n == 1 {
                snakes = [Snake(Cell(cols - 4, rows / 2), Cell(-1, 0))]
                apple = Snake(Cell(cols / 4, rows / 2), Cell(1, 0), length: 1)
            } else {
                snakes = starts.prefix(n).map { Snake($0.0, $0.1) }
                apple = Snake(Cell(cols / 2, rows / 2), Cell(1, 0), length: 1)
            }
            slots = []
            var k = 0
            for slot in 0..<players {
                if slot == aSlot {
                    slots.append(Slot(isApple: true, k: 0))
                } else {
                    slots.append(Slot(isApple: false, k: k))
                    k += 1
                }
            }
        } else if players == 1 {
            snakes = [Snake(Cell(cols / 3, rows / 2), Cell(1, 0))]
        } else {
            snakes = starts.prefix(players).map { Snake($0.0, $0.1) }
        }
        walls = [:]
        foods = []
        state = players == 1 ? .idle : .countdown
        cd = countdown
        winner = nil
        win = false
        newBest = false
        acc = 0
        clock = 0
        deadAt = 0
        tickNo = 0
        lastDying = []
        events = []
        if !remote {
            if players == 1 && mode != "Apple" {
                _ = spawnFood(Cell(cols * 2 / 3 + 1, rows / 2))
            }
            fillFoods()
        }
    }

    func snakeOf(_ slot: Int) -> Int? {
        if apple != nil {
            if players == 1 || slot >= slots.count || slots[slot].isApple { return nil }
            return slots[slot].k
        }
        return slot < snakes.count ? slot : nil
    }

    func slotOfSnake(_ i: Int) -> Int? {
        if apple != nil && players > 1 {
            return slots.firstIndex { !$0.isApple && $0.k == i }
        }
        return i
    }

    func timeLeft() -> Double {
        max(0, APPLE_TIME - Double(tickNo) * interval())
    }

    @discardableResult
    func spawnFood(_ at: Cell? = nil) -> Bool {
        var cell = at
        if cell == nil {
            var taken = Set(walls.keys)
            for f in foods { taken.insert(f.cell) }
            for s in snakes where !s.gone { taken.formUnion(s.body) }
            var free: [Cell] = []
            for x in 0..<cols {
                for y in 0..<rows where !taken.contains(Cell(x, y)) {
                    free.append(Cell(x, y))
                }
            }
            guard let pick = free.randomElement() else { return false }
            cell = pick
        }
        foods.append(Food(cell: cell!, born: clock))
        return true
    }

    func fillFoods() {
        if remote || mode == "Apple" { return }
        var target = cfg.apples
        if players > 1 { target = max(target, players) }
        while foods.count < target {
            if !spawnFood() { break }
        }
        while foods.count > target { foods.removeLast() }
        if foods.isEmpty && state != .dead {
            win = true
            endRound()
        }
    }

    func interval() -> Double {
        if remote { return iv }
        var cps = SPEEDS[cfg["speed"]] ?? 9
        if mode == "Rush" {
            let top = Double(snakes.map(\.score).max() ?? 0)
            cps = min(cps + 0.5 * top, cps * 2.5, 30.0)
        }
        return 1.0 / cps
    }

    var t: Double {
        if state == .idle || state == .countdown { return 1.0 }
        return clamp(acc / interval(), 0, 1)
    }

    func update(_ dt: Double, simulate: Bool = true) {
        clock += dt
        if state == .countdown {
            cd -= dt
            if cd <= 0 && !remote && simulate {
                cd = 0
                state = .running
                acc = 0
                tick()
            } else {
                cd = max(cd, 0)
            }
            return
        }
        if state == .idle || (state == .running && !simulate) { return }
        acc += dt
        var step = interval()
        if state == .running && !remote {
            var guardCount = 0
            while acc >= step && state == .running && guardCount < 6 {
                acc -= step
                tick()
                step = interval()
                guardCount += 1
            }
        }
        acc = min(acc, step)
    }

    func steer(_ idx: Int, _ raw: Cell) {
        if remote || state == .dead { return }
        var si = idx
        if apple != nil {
            if players == 1 || (idx < slots.count && slots[idx].isApple) {
                steerApple(raw)
                return
            }
            guard idx < slots.count else { return }
            si = slots[idx].k
        }
        guard si < snakes.count else { return }
        let s = snakes[si]
        if !s.alive { return }
        var d = raw
        if mode == "Mirror" { d = Cell(-d.x, d.y) }
        if TWIN_INVERTS_CONTROLS && mode == "Twin" && s.twinFlip { d = Cell(-d.x, -d.y) }

        if state == .idle {
            if d == Cell(-1, 0) {
                let h = s.body[0]
                s.body = (0..<s.body.count).map { Cell(h.x + $0, h.y) }
            }
            s.dir = d
            s.still()
            state = .running
            acc = 0
            tick()
            return
        }
        let last = s.queue.last ?? s.dir
        if d == last || d == Cell(-last.x, -last.y) { return }
        if s.queue.count < 3 { s.queue.append(d) }
    }

    private func steerApple(_ raw: Cell) {
        held.removeAll { $0 == raw }
        held.append(raw)
        if appleQueue.count < 2 { appleQueue.append(raw) }
        if state == .idle {
            state = .running
            acc = 0
            tick()
        }
    }

    @discardableResult
    func teleport() -> Bool {
        guard let a = apple, a.alive, state == .running, teleports > 0 else { return false }
        let heads = snakes.filter(\.alive).map { $0.body[0] }
        if heads.isEmpty { return false }
        var blocked = Set(walls.keys)
        for s in snakes where !s.gone { blocked.formUnion(s.body) }
        var reach = Set(heads)
        var todo = heads
        var head = 0
        while head < todo.count {
            let c = todo[head]
            head += 1
            for d in DIRS {
                let n = Cell(c.x + d.x, c.y + d.y)
                if n.x >= 0 && n.x < cols && n.y >= 0 && n.y < rows && !blocked.contains(n) && !reach.contains(n) {
                    reach.insert(n)
                    todo.append(n)
                }
            }
        }
        reach.subtract(heads)
        let cur = a.body[0]
        let far = reach.filter { c in
            c != cur && heads.allSatisfy { abs(c.x - $0.x) + abs(c.y - $0.y) >= TELEPORT_MIN_DIST }
        }
        let pool = far.isEmpty ? reach.filter { $0 != cur } : far
        guard let new = pool.randomElement() else { return false }
        a.body = [new]
        a.still()
        appleQueue.removeAll()
        teleports -= 1
        events.append(GameEvent(kind: "poof", cell: cur, idx: 0))
        events.append(GameEvent(kind: "poof", cell: new, idx: 0))
        return true
    }

    func release(_ raw: Cell) {
        held.removeAll { $0 == raw }
    }

    private func appleStep() {
        guard let a = apple else { return }
        let d: Cell? = appleQueue.isEmpty ? held.last : appleQueue.removeFirst()
        a.hFrom = a.body[0]
        if let d {
            let n = Cell(a.body[0].x + d.x, a.body[0].y + d.y)
            var solid = Set(walls.keys)
            for s in snakes {
                if s.alive {
                    solid.formUnion(s.body.dropFirst())
                } else if !s.gone {
                    solid.formUnion(s.body)
                }
            }
            if n.x >= 0 && n.x < cols && n.y >= 0 && n.y < rows && !solid.contains(n) {
                a.body = [n]
                a.dir = d
            }
        }
        a.hTo = a.body[0]
        for (i, s) in snakes.enumerated() where s.alive && s.body[0] == a.body[0] {
            for t in snakes { t.still() }
            eaten(by: i)
            return
        }
        if players == 1 {
            let s = snakes[0]
            s.queue.removeAll()
            s.dir = aiDir(s, goal: a.body[0])
        }
    }

    private func aiDir(_ s: Snake, goal: Cell) -> Cell {
        let head = s.body[0]
        var blocked = Set(walls.keys)
        blocked.formUnion(s.grow > 0 ? s.body : Array(s.body.dropLast()))
        let c0 = cols
        let r0 = rows
        func free(_ c: Cell) -> Bool {
            c.x >= 0 && c.x < c0 && c.y >= 0 && c.y < r0 && !blocked.contains(c)
        }
        let options = DIRS.filter { free(Cell(head.x + $0.x, head.y + $0.y)) }
        if options.isEmpty { return s.dir }
        var prev: [Cell: Cell] = [head: head]
        var queue = [head]
        var qi = 0
        while qi < queue.count && prev[goal] == nil {
            let c = queue[qi]
            qi += 1
            for d in DIRS {
                let n = Cell(c.x + d.x, c.y + d.y)
                if free(n) && prev[n] == nil {
                    prev[n] = c
                    queue.append(n)
                }
            }
        }
        if Double.random(in: 0..<1) < APPLE_MISTAKE {
            return options.randomElement()!
        }
        if prev[goal] != nil && goal != head {
            var step = goal
            while let p = prev[step], p != head {
                step = p
            }
            return Cell(step.x - head.x, step.y - head.y)
        }
        func room(_ c: Cell) -> Int {
            var seen: Set<Cell> = [c]
            var todo = [c]
            var ti = 0
            while ti < todo.count && seen.count < 60 {
                let x = todo[ti]
                ti += 1
                for d in DIRS {
                    let n = Cell(x.x + d.x, x.y + d.y)
                    if free(n) && !seen.contains(n) {
                        seen.insert(n)
                        todo.append(n)
                    }
                }
            }
            return seen.count
        }
        return options.max { room(Cell(head.x + $0.x, head.y + $0.y)) < room(Cell(head.x + $1.x, head.y + $1.y)) }!
    }

    private func appleAfter() {
        guard let a = apple else { return }
        for (i, s) in snakes.enumerated() where s.alive && s.body[0] == a.body[0] {
            eaten(by: i)
            return
        }
        if players == 1 {
            a.score = Int(Double(tickNo) * interval())
        } else if timeLeft() <= 0 {
            why = "time"
            endRound()
            return
        }
        if tickNo % APPLE_GROW_TICKS == 0 {
            for s in snakes where s.alive { s.grow += 1 }
        }
    }

    private func eaten(by: Int?) {
        guard let a = apple else { return }
        a.alive = false
        why = "eaten"
        events.append(GameEvent(kind: "eaten", cell: a.body[0], idx: 0))
        if players > 1, let by { winner = slotOfSnake(by) }
        endRound()
    }

    func tick() {
        tickNo += 1
        if apple != nil {
            appleStep()
            if state == .dead { return }
            if tickNo % APPLE_SNAKE_PAUSE == 0 {
                for s in snakes { s.still() }
                appleAfter()
                return
            }
        }
        for s in snakes where !s.alive && !s.gone && players > 1 && clock - s.died >= CORPSE_TIME {
            s.gone = true
        }
        let alive = snakes.indices.filter { snakes[$0].alive }
        for i in alive {
            let s = snakes[i]
            if !s.queue.isEmpty { s.dir = s.queue.removeFirst() }
        }
        let wrap = mode == "No Borders"
        var plan: [Int: Cell] = [:]
        for i in alive {
            let s = snakes[i]
            var nx = s.body[0].x + s.dir.x
            var ny = s.body[0].y + s.dir.y
            if wrap {
                nx = ((nx % cols) + cols) % cols
                ny = ((ny % rows) + rows) % rows
            } else if !(nx >= 0 && nx < cols && ny >= 0 && ny < rows) {
                continue
            }
            plan[i] = Cell(nx, ny)
        }
        var targetCount: [Cell: Int] = [:]
        for c in plan.values { targetCount[c, default: 0] += 1 }
        let foodCells = Set(foods.map(\.cell))
        var eats: [Int: Bool] = [:]
        var grows: [Int: Bool] = [:]
        for i in alive {
            if let p = plan[i] {
                eats[i] = foodCells.contains(p) && targetCount[p] == 1
            } else {
                eats[i] = false
            }
            grows[i] = (eats[i]! && mode != "Wall") || snakes[i].grow > 0
        }
        var solid = Set(walls.keys)
        for i in alive {
            let s = snakes[i]
            solid.formUnion(grows[i]! ? s.body : Array(s.body.dropLast()))
        }
        for s in snakes where !s.alive && !s.gone { solid.formUnion(s.body) }
        let dying = alive.filter { i in
            guard let p = plan[i] else { return true }
            return solid.contains(p) || (targetCount[p] ?? 0) > 1
        }
        let dyingSet = Set(dying)

        for i in alive {
            let s = snakes[i]
            if dyingSet.contains(i) {
                s.alive = false
                s.still()
                s.died = clock
                events.append(GameEvent(kind: "die", cell: s.body[0], idx: i))
                continue
            }
            let new = plan[i]!
            let prev = s.body
            var body = [new] + prev
            var tail: Cell?
            if !grows[i]! { tail = body.removeLast() }
            if grows[i]! && !eats[i]! && s.grow > 0 { s.grow -= 1 }
            s.body = body
            s.hFrom = prev[0]
            s.hTo = new
            s.pathCells = Array(body.dropFirst())
            s.tFrom = tail ?? body[body.count - 1]
            s.tTo = body[body.count - 1]
            if eats[i]! {
                if let fi = foods.firstIndex(where: { $0.cell == new }) { foods.remove(at: fi) }
                s.score += 1
                events.append(GameEvent(kind: "eat", cell: new, idx: i))
                if mode == "Wall", let tail { walls[tail] = clock }
                if mode == "Twin" { reverse(s, i) }
            }
        }
        fillFoods()
        let survivors = snakes.filter(\.alive).count
        lastDying = dying
        if !dying.isEmpty && (players == 1 || survivors <= (apple != nil ? 0 : 1)) {
            if apple != nil && players > 1 { why = "crashed" }
            endRound()
        }
        if apple != nil && state != .dead { appleAfter() }
    }

    private func reverse(_ s: Snake, _ idx: Int) {
        s.body.reverse()
        let b = s.body
        s.pathCells = Array(b.dropLast())
        s.hFrom = b[0]
        s.hTo = b[0]
        s.tFrom = b[b.count - 2]
        s.tTo = b[b.count - 1]
        s.dir = Cell(wrapStepInt(b[0].x - b[1].x, cols), wrapStepInt(b[0].y - b[1].y, rows))
        s.queue.removeAll()
        s.twinFlip.toggle()
        events.append(GameEvent(kind: "reverse", cell: b[0], idx: idx))
    }

    func endRound() {
        if state == .dead { return }
        state = .dead
        deadAt = clock
        if players == 1 {
            if let a = apple, a.alive {
                win = true
                a.score += APPLE_WIN_BONUS
            }
            recordBest()
        } else if let a = apple {
            if a.alive {
                winner = appleSlot
                if why.isEmpty { why = "crashed" }
            }
        } else {
            let alive = snakes.indices.filter { snakes[$0].alive }
            if alive.count == 1 {
                winner = alive[0]
            } else {
                let pool = lastDying.isEmpty ? Array(snakes.indices) : lastDying
                let top = pool.map { snakes[$0].score }.max() ?? 0
                let leaders = pool.filter { snakes[$0].score == top }
                winner = leaders.count == 1 ? leaders[0] : -1
            }
        }
    }

    func dropPlayer(_ idxIn: Int) {
        if state == .dead { return }
        var idx = idxIn
        if apple != nil && players > 1 {
            guard idx < slots.count else { return }
            let slot = slots[idx]
            if slot.isApple {
                apple?.alive = false
                why = "left"
                let alive = snakes.indices.filter { snakes[$0].alive }
                winner = alive.first.flatMap { slotOfSnake($0) } ?? -1
                endRound()
                return
            }
            idx = slot.k
        }
        guard idx < snakes.count else { return }
        let s = snakes[idx]
        if !s.alive { return }
        s.alive = false
        s.still()
        s.died = clock
        events.append(GameEvent(kind: "die", cell: s.body[0], idx: idx))
        if apple != nil && players > 1 {
            if !snakes.contains(where: \.alive) {
                why = "crashed"
                endRound()
            }
        } else if snakes.filter(\.alive).count <= 1 {
            lastDying = [idx]
            endRound()
        }
    }

    private func recordBest() {
        if score > (cfg.best[mode] ?? 0) {
            cfg.best[mode] = score
            newBest = score > 0
            cfg.save()
        }
    }

    func snapshot() -> [String: Any] {
        [
            "t": "state", "tick": tickNo, "state": state.rawValue, "iv": interval(),
            "cd": cd, "winner": winner.map { $0 as Any } ?? NSNull(), "foods": foods.map { $0.cell.json },
            "walls": walls.keys.map(\.json), "snakes": snakes.map { $0.toDict() },
            "apple": apple.map { $0.toDict() as Any } ?? NSNull(),
            "tp": teleports, "why": why,
            "events": events.map { [$0.kind, $0.cell.json, $0.idx] as [Any] },
        ]
    }

    func applySnapshot(_ d: [String: Any]) {
        let newState = GameState(rawValue: d["state"] as? String ?? "") ?? state
        if newState == .dead && state != .dead { deadAt = clock }
        state = newState
        iv = (d["iv"] as? NSNumber)?.doubleValue ?? iv
        cd = (d["cd"] as? NSNumber)?.doubleValue ?? cd
        winner = (d["winner"] as? NSNumber)?.intValue
        teleports = (d["tp"] as? NSNumber)?.intValue ?? 0
        why = d["why"] as? String ?? ""
        var known: [Cell: Double] = [:]
        for f in foods { known[f.cell] = f.born }
        foods = Cell.list(d["foods"]).map { Food(cell: $0, born: known[$0] ?? clock) }
        var newWalls: [Cell: Double] = [:]
        for c in Cell.list(d["walls"]) { newWalls[c] = walls[c] ?? clock }
        walls = newWalls
        if let list = d["snakes"] as? [Any] {
            for (s, sd) in zip(snakes, list) {
                if let sd = sd as? [String: Any] { s.load(sd) }
            }
        }
        if let a = apple, let ad = d["apple"] as? [String: Any] { a.load(ad) }
        if let evs = d["events"] as? [Any] {
            for e in evs {
                guard let arr = e as? [Any], arr.count >= 3, let kind = arr[0] as? String,
                      let cell = Cell.from(arr[1]), let idx = (arr[2] as? NSNumber)?.intValue else { continue }
                events.append(GameEvent(kind: kind, cell: cell, idx: idx))
            }
        }
        if let tick = (d["tick"] as? NSNumber)?.intValue, tick != tickNo {
            tickNo = tick
            acc = 0
        }
    }
}
