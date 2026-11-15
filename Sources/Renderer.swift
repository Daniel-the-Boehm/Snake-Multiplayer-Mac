import SwiftUI

struct BoardLayout {
    let cell: Double
    let board: CGRect

    init(size: CGSize, cols: Int, rows: Int) {
        let margin = clamp(min(size.width, size.height) * 0.025, 6, 24)
        let c = max(6, floor(min((size.width - 2 * margin) / Double(cols), (size.height - 2 * margin) / Double(rows))))
        let bw = c * Double(cols)
        let bh = c * Double(rows)
        cell = c
        board = CGRect(x: floor((size.width - bw) / 2), y: floor((size.height - bh) / 2), width: bw, height: bh)
    }

    var radius: Double { max(6, floor(cell / 3)) }
}

func roundedPath(_ r: CGRect, _ radius: Double) -> Path {
    let rad = max(0, min(radius, r.width / 2, r.height / 2))
    return Path(roundedRect: r, cornerRadius: rad, style: .continuous)
}

func circlePath(_ c: CGPoint, _ r: Double) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}

func drawFruit(_ ctx: GraphicsContext, _ kind: String, in rect: CGRect) {
    var g = ctx
    g.translateBy(x: rect.minX, y: rect.minY)
    g.scaleBy(x: rect.width / 100, y: rect.height / 100)
    g.translateBy(x: 50, y: 52)
    g.scaleBy(x: 1.16, y: 1.16)
    g.translateBy(x: -50, y: -52)

    func circle(_ c: RGB, _ x: Double, _ y: Double, _ r: Double) {
        g.fill(circlePath(CGPoint(x: x, y: y), r), with: .color(c.color))
    }
    func poly(_ c: RGB, _ pts: [(Double, Double)]) {
        var p = Path()
        p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        g.fill(p, with: .color(c.color))
    }
    func line(_ c: RGB, _ a: (Double, Double), _ b: (Double, Double), _ w: Double) {
        var p = Path()
        p.move(to: CGPoint(x: a.0, y: a.1))
        p.addLine(to: CGPoint(x: b.0, y: b.1))
        g.stroke(p, with: .color(c.color), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }
    func ellipse(_ c: RGB, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(c.color))
    }

    let leaf = RGB(104, 184, 66)
    let leafDark = RGB(66, 134, 48)
    let brown = RGB(112, 72, 40)
    switch kind {
    case "Cherry":
        line(RGB(88, 126, 58), (35, 68), (56, 15), 3.2)
        line(RGB(88, 126, 58), (68, 62), (56, 15), 3.2)
        poly(leafDark, [(56, 16), (72, 6), (88, 15), (72, 23)])
        poly(leaf, [(57, 16), (72, 9), (84, 15), (72, 21)])
        for (x, y) in [(33.0, 71.0), (68.0, 65.0)] {
            circle(RGB(128, 12, 36), x, y, 21)
            circle(RGB(190, 24, 50), x, y, 18.5)
            circle(RGB(244, 118, 126), x - 6, y - 7, 5)
        }
    case "Orange":
        circle(RGB(208, 104, 14), 50, 57, 38)
        circle(RGB(255, 152, 32), 50, 57, 35)
        ellipse(RGB(255, 200, 118), 28, 36, 16, 22)
        circle(RGB(224, 120, 20), 50, 30, 3)
        poly(leafDark, [(50, 24), (66, 11), (82, 19), (66, 30)])
        poly(leaf, [(51, 23), (65, 13), (78, 19), (65, 27)])
    case "Lemon":
        circle(RGB(196, 160, 18), 10, 52, 8)
        circle(RGB(196, 160, 18), 90, 52, 8)
        ellipse(RGB(196, 160, 18), 8, 27, 84, 54)
        circle(RGB(250, 222, 64), 11, 52, 6)
        circle(RGB(250, 222, 64), 89, 52, 6)
        ellipse(RGB(250, 222, 64), 11, 30, 78, 48)
        ellipse(RGB(255, 246, 160), 26, 38, 28, 10)
        poly(leafDark, [(56, 32), (72, 14), (88, 22), (72, 36)])
        poly(leaf, [(58, 31), (72, 17), (84, 22), (72, 32)])
    case "Grapes":
        let spots: [(Double, Double)] = [(32, 42), (52, 42), (72, 42), (42, 60), (62, 60), (52, 78)]
        for (x, y) in spots { circle(RGB(84, 34, 134), x, y, 16.5) }
        for (x, y) in spots {
            circle(RGB(132, 66, 190), x, y, 14)
            circle(RGB(196, 148, 238), x - 4.5, y - 4.5, 3.6)
        }
        line(brown, (52, 30), (55, 13), 4.5)
        poly(leafDark, [(56, 22), (72, 8), (88, 16), (74, 28)])
        poly(leaf, [(57, 21), (72, 11), (84, 16), (73, 25)])
    default:
        let lobes: [(Double, Double, Double)] = [(38, 58, 27), (62, 58, 27), (50, 63, 29)]
        for (x, y, r) in lobes { circle(RGB(170, 36, 38), x, y, r + 2.5) }
        for (x, y, r) in lobes { circle(RGB(226, 60, 52), x, y, r) }
        ellipse(RGB(248, 130, 112), 25, 44, 12, 19)
        line(brown, (50, 36), (53, 17), 4.5)
        poly(leafDark, [(53, 25), (68, 12), (82, 19), (70, 31)])
        poly(leaf, [(54, 24), (67, 14), (78, 19), (68, 28)])
    }
}

func drawPhotoFruit(_ ctx: GraphicsContext, _ photo: CGImage, in rect: CGRect) {
    let side = rect.width
    let d = side * 0.9
    let rim = max(0.5, side * 0.035)
    let c = CGPoint(x: rect.midX, y: rect.midY)
    ctx.fill(circlePath(c, d / 2 + rim), with: .color(RGB(30, 30, 50).color))
    var g = ctx
    let inner = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
    g.clip(to: Path(ellipseIn: inner))
    g.draw(Image(decorative: photo, scale: 1), in: inner)
}

func buildRuns(_ pts: [CGPoint]) -> [CGRect] {
    guard var prev = pts.first else { return [] }
    var runs: [CGRect] = []
    var cur = (prev.x, prev.y, prev.x, prev.y)
    var axis: Character?
    for p in pts.dropFirst() {
        let dx = p.x - prev.x
        let dy = p.y - prev.y
        if abs(dx) < 1e-6 && abs(dy) < 1e-6 { continue }
        let a: Character = abs(dx) > abs(dy) ? "h" : "v"
        if let ax = axis, ax != a {
            runs.append(CGRect(x: cur.0, y: cur.1, width: cur.2 - cur.0, height: cur.3 - cur.1))
            cur = (prev.x, prev.y, prev.x, prev.y)
        }
        axis = a
        cur.0 = min(cur.0, p.x)
        cur.1 = min(cur.1, p.y)
        cur.2 = max(cur.2, p.x)
        cur.3 = max(cur.3, p.y)
        prev = p
    }
    runs.append(CGRect(x: cur.0, y: cur.1, width: cur.2 - cur.0, height: cur.3 - cur.1))
    return runs
}

func seamPoints(_ pts: [CGPoint], start: Double, step: Double) -> [(CGPoint, Bool)] {
    var out: [(CGPoint, Bool)] = []
    var next = start
    var acc = 0.0
    guard pts.count > 1 else { return out }
    for i in 0..<(pts.count - 1) {
        let a = pts[i]
        let b = pts[i + 1]
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = hypot(dx, dy)
        if len < 1e-6 { continue }
        while next <= acc + len {
            let f = (next - acc) / len
            out.append((CGPoint(x: a.x + dx * f, y: a.y + dy * f), abs(dx) > abs(dy)))
            next += step
        }
        acc += len
    }
    return out
}

struct Renderer {
    let m: AppModel

    func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let g = m.game
        let th = m.cfg.theme
        let lay = BoardLayout(size: size, cols: g.cols, rows: g.rows)
        let cell = lay.cell
        var ox = lay.board.minX
        var oy = lay.board.minY
        if m.shake > 0 {
            let amp = cell * 0.14 * m.shake
            ox += Double.random(in: -amp...amp).rounded()
            oy += Double.random(in: -amp...amp).rounded()
        }
        let rad = lay.radius
        let br = CGRect(x: ox, y: oy, width: lay.board.width, height: lay.board.height)

        var shadow = ctx
        shadow.addFilter(.blur(radius: 14))
        shadow.fill(roundedPath(br.offsetBy(dx: 0, dy: 10), rad), with: .color(.black.opacity(0.35)))
        ctx.fill(roundedPath(br.offsetBy(dx: 0, dy: 5), rad), with: .color(th.window.mix(.black, 0.35).color))

        drawBase(ctx, th, br, cell, rad)

        var c = ctx
        c.clip(to: Path(br))
        drawWalls(c, th, ox, oy, cell)
        drawFoods(c, ox, oy, cell)
        drawApple(c, th, ox, oy, cell)
        drawRings(c, th, ox, oy, cell)
        for i in 0..<min(m.anims.count, g.snakes.count) where !g.snakes[i].gone {
            drawSnake(c, ox, oy, cell, i)
        }
        for p in m.particles {
            let s = max(1, p.size * cell * (p.life / p.total) * 1.6)
            let r = CGRect(x: ox + p.x * cell - s / 2, y: oy + p.y * cell - s / 2, width: s, height: s)
            c.fill(roundedPath(r, s / 3), with: .color(p.color.color))
        }

        let rim = Gradient(colors: [.white.opacity(0.45), .white.opacity(0.0), .white.opacity(0.18)])
        ctx.stroke(roundedPath(br.insetBy(dx: 0.5, dy: 0.5), rad), with: .linearGradient(
            rim, startPoint: CGPoint(x: br.minX, y: br.minY), endPoint: CGPoint(x: br.maxX, y: br.maxY)), lineWidth: 1)

        if m.boardDimmed {
            ctx.fill(roundedPath(br, rad), with: .color(.black.opacity(120.0 / 255.0)))
        }
    }

    private func drawBase(_ ctx: GraphicsContext, _ th: Theme, _ br: CGRect, _ cell: Double, _ rad: Double) {
        let g = m.game
        var b = ctx
        b.clip(to: roundedPath(br, rad))
        b.fill(Path(br), with: .color(th.boardB.color))
        var checker = Path()
        for y in 0..<g.rows {
            for x in 0..<g.cols where (x + y) % 2 == 0 {
                checker.addRect(CGRect(x: br.minX + Double(x) * cell, y: br.minY + Double(y) * cell, width: cell, height: cell))
            }
        }
        b.fill(checker, with: .color(th.boardA.color))
        if let photo = m.bgPhoto() {
            let iw = Double(photo.width)
            let ih = Double(photo.height)
            let s = max(br.width / iw, br.height / ih)
            let cover = CGRect(x: br.midX - iw * s / 2, y: br.midY - ih * s / 2, width: iw * s, height: ih * s)
            b.draw(Image(decorative: photo, scale: 1), in: cover)
            b.fill(checker, with: .color(.white.opacity(24.0 / 255.0)))
            b.fill(Path(br), with: .color(.black.opacity(40.0 / 255.0)))
        }
        let bw = max(2, floor(cell / 12))
        if g.mode == "No Borders" {
            let dash = max(4, floor(cell / 3))
            let gap = max(3, floor(cell / 4))
            let col = th.frame.mix(th.boardA, 0.25).color
            var dashes = Path()
            var x = rad
            while x < br.width - rad {
                dashes.addRect(CGRect(x: br.minX + x, y: br.minY + floor(bw / 2), width: dash, height: bw))
                dashes.addRect(CGRect(x: br.minX + x, y: br.maxY - bw - floor(bw / 2), width: dash, height: bw))
                x += dash + gap
            }
            var y = rad
            while y < br.height - rad {
                dashes.addRect(CGRect(x: br.minX + floor(bw / 2), y: br.minY + y, width: bw, height: dash))
                dashes.addRect(CGRect(x: br.maxX - bw - floor(bw / 2), y: br.minY + y, width: bw, height: dash))
                y += dash + gap
            }
            b.fill(dashes, with: .color(col))
        } else {
            b.stroke(roundedPath(br.insetBy(dx: bw / 2, dy: bw / 2), rad - bw / 2), with: .color(th.frame.color), lineWidth: bw)
        }
    }

    private func drawWalls(_ ctx: GraphicsContext, _ th: Theme, _ ox: Double, _ oy: Double, _ cell: Double) {
        let g = m.game
        for (w, born) in g.walls {
            let size = floor(cell * 0.94 * easeOutBack((g.clock - born) / 0.28))
            if size < 2 { continue }
            let cx = ox + (Double(w.x) + 0.5) * cell
            let cy = oy + (Double(w.y) + 0.5) * cell
            let r = CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
            let bev = max(2, floor(size / 9))
            let corner = max(2, floor(size / 5))
            ctx.fill(roundedPath(r, corner), with: .color(th.wallLo.color))
            ctx.fill(roundedPath(CGRect(x: r.minX, y: r.minY, width: r.width - bev, height: r.height - bev), corner),
                     with: .color(th.wall.color))
            ctx.fill(roundedPath(CGRect(x: r.minX + bev, y: r.minY + bev, width: max(2, floor(r.width / 3)), height: bev), bev / 2),
                     with: .color(th.wallHi.color))
        }
    }

    private func fruitSprite(_ ctx: GraphicsContext, in rect: CGRect) {
        if m.fruitPhotoOn(), let photo = m.photos["fruit_photo"] {
            drawPhotoFruit(ctx, photo, in: rect)
        } else {
            drawFruit(ctx, m.cfg["fruit"], in: rect)
        }
    }

    private func drawFoods(_ ctx: GraphicsContext, _ ox: Double, _ oy: Double, _ cell: Double) {
        let g = m.game
        func blit(_ x: Int, _ y: Int, _ scale: Double, _ bob: Double) {
            let px = ox + Double(x) * cell
            let py = oy + Double(y) * cell
            let sh = CGRect(x: px + cell * 0.2, y: py + cell * 0.74, width: cell * 0.6, height: max(2, cell * 0.18))
            ctx.fill(Path(ellipseIn: sh), with: .color(.black.opacity(55.0 / 255.0)))
            if scale > 0.02 {
                let sz = cell * scale
                fruitSprite(ctx, in: CGRect(x: px + (cell - sz) / 2, y: py + (cell - sz) / 2 + bob, width: sz, height: sz))
            }
        }
        for f in g.foods {
            let bob = sin(m.time * 4 + Double(f.cell.x) * 1.3 + Double(f.cell.y) * 0.7) * cell * 0.03
            blit(f.cell.x, f.cell.y, easeOutBack((g.clock - f.born) / 0.3), bob)
        }
        for fx in m.eatFx {
            let p = (m.time - fx.start) / fx.dur
            blit(fx.cell.x, fx.cell.y, 1 - smoothstep((p - 0.55) / 0.45), 0)
        }
    }

    private func drawRings(_ ctx: GraphicsContext, _ th: Theme, _ ox: Double, _ oy: Double, _ cell: Double) {
        for r in m.rings {
            let p = (m.time - r.born) / 0.4
            let radius = cell * (0.3 + p)
            let width = max(1, cell * 0.14 * (1 - p))
            ctx.stroke(circlePath(CGPoint(x: ox + r.x * cell, y: oy + r.y * cell), radius),
                       with: .color(RGB.white.mix(th.accent, p).color), lineWidth: width)
        }
    }

    private func drawApple(_ ctx: GraphicsContext, _ th: Theme, _ ox: Double, _ oy: Double, _ cell: Double) {
        let g = m.game
        guard let a = g.apple, a.alive else { return }
        let t = g.t
        let x = lerp(Double(a.hFrom.x), Double(a.hTo.x), t) + 0.5
        let y = lerp(Double(a.hFrom.y), Double(a.hTo.y), t) + 0.5
        let bob = sin(m.time * 7) * cell * 0.03
        let cx = ox + x * cell
        let cy = oy + y * cell + bob
        let ring = cell * (0.62 + 0.04 * sin(m.time * 6))
        let rw = max(3, floor(cell / 12))
        ctx.stroke(circlePath(CGPoint(x: cx, y: cy), ring + 1 - (rw + 2) / 2), with: .color(RGB(30, 30, 50).color), lineWidth: rw + 2)
        ctx.stroke(circlePath(CGPoint(x: cx, y: cy), ring - rw / 2), with: .color(th.accent.color), lineWidth: rw)
        fruitSprite(ctx, in: CGRect(x: cx - cell / 2, y: cy - cell / 2, width: cell, height: cell))
        if m.fruitPhotoOn() { return }
        var heads: [CGPoint] = []
        for (anim, s) in zip(m.anims, g.snakes) where s.alive {
            if let p = anim.pts.first { heads.append(p) }
        }
        if heads.isEmpty, let p = m.anims.first?.pts.first { heads = [p] }
        guard let target = heads.min(by: { hypot($0.x - x, $0.y - y) < hypot($1.x - x, $1.y - y) }) else { return }
        let dx = target.x - x
        let dy = target.y - y
        let dist = hypot(dx, dy) == 0 ? 1 : hypot(dx, dy)
        let er = cell * (dist < 3.5 ? 0.135 : 0.105)
        for side in [-1.0, 1.0] {
            let e = CGPoint(x: cx + side * cell * 0.17, y: cy - cell * 0.02)
            ctx.fill(circlePath(e, er + 2), with: .color(RGB(30, 30, 50).color))
            ctx.fill(circlePath(e, er), with: .color(.white))
            ctx.fill(circlePath(CGPoint(x: e.x + dx / dist * er * 0.5, y: e.y + dy / dist * er * 0.5), max(1, er * 0.5)),
                     with: .color(RGB(20, 22, 40).color))
        }
    }

    private func drawSnake(_ ctx: GraphicsContext, _ ox: Double, _ oy: Double, _ cell: Double, _ i: Int) {
        let g = m.game
        let st = m.style(m.styleOf(i))
        let pts = m.anims[i].pts
        guard !pts.isEmpty else { return }

        var offsets: [(Double, Double)] = [(0, 0)]
        if g.mode == "No Borders" {
            let xs = pts.map(\.x)
            let ys = pts.map(\.y)
            let cols = Double(g.cols)
            let rows = Double(g.rows)
            let kx0 = Int(floor((-xs.max()! - 0.5) / cols)) + 1
            let kx1 = Int(ceil((cols - xs.min()! + 0.5) / cols)) - 1
            let ky0 = Int(floor((-ys.max()! - 0.5) / rows)) + 1
            let ky1 = Int(ceil((rows - ys.min()! + 0.5) / rows)) - 1
            offsets = []
            if kx0 <= kx1 && ky0 <= ky1 {
                for kx in kx0...kx1 {
                    for ky in ky0...ky1 { offsets.append((Double(kx) * cols, Double(ky) * rows)) }
                }
            }
        }

        let bodyW = cell * 0.78
        let half = bodyW / 2
        let ol = max(2, (cell * 0.07).rounded())
        let radius = floor(bodyW * st.radius)
        for (sx, sy) in offsets {
            let P = pts.map { CGPoint(x: ox + ($0.x + sx) * cell, y: oy + ($0.y + sy) * cell) }
            let rects = buildRuns(P).map { r in
                CGRect(x: r.minX - half, y: r.minY - half, width: r.width + bodyW, height: r.height + bodyW)
            }
            var outline = Path()
            for r in rects { outline.addPath(roundedPath(r.insetBy(dx: -ol, dy: -ol), radius + ol)) }
            ctx.fill(outline, with: .color(st.outline.color))
            var body = Path()
            for r in rects { body.addPath(roundedPath(r, radius)) }
            ctx.fill(body, with: .color(st.body.color))
            if let shine = st.shine {
                var hl = Path()
                for r in rects {
                    let h: CGRect
                    if r.width >= r.height {
                        h = CGRect(x: r.minX + 0.22 * bodyW, y: r.minY + 0.14 * bodyW, width: r.width - 0.44 * bodyW, height: 0.2 * bodyW)
                    } else {
                        h = CGRect(x: r.minX + 0.14 * bodyW, y: r.minY + 0.22 * bodyW, width: 0.2 * bodyW, height: r.height - 0.44 * bodyW)
                    }
                    if h.width > 1 && h.height > 1 { hl.addPath(roundedPath(h, min(h.width, h.height) / 2)) }
                }
                ctx.fill(hl, with: .color(shine.color))
            }
            if let seam = st.seam {
                var lines = Path()
                for (p, horizontal) in seamPoints(P, start: 1.5 * cell, step: cell) {
                    if horizontal {
                        lines.move(to: CGPoint(x: p.x, y: p.y + half - ol))
                        lines.addLine(to: CGPoint(x: p.x, y: p.y - (half - ol)))
                    } else {
                        lines.move(to: CGPoint(x: p.x + half - ol, y: p.y))
                        lines.addLine(to: CGPoint(x: p.x - (half - ol), y: p.y))
                    }
                }
                ctx.stroke(lines, with: .color(seam.color), lineWidth: max(2, floor(cell / 14)))
            }
            drawHead(ctx, P[0], cell, i, st)
        }
    }

    private func drawHead(_ ctx: GraphicsContext, _ c: CGPoint, _ cell: Double, _ i: Int, _ st: SnakeStyle) {
        let g = m.game
        let view = m.anims[i]
        let dead = !g.snakes[i].alive
        let u = cell * 0.96
        let ol = max(2, (cell * 0.07).rounded())

        if i == m.photoSnake(), let photo = m.headPhoto() {
            let rf = max(st.radius, 0.30)
            let size = u * (1 + 0.10 * view.mouth)
            let rect = CGRect(x: c.x - size / 2, y: c.y - size / 2, width: size, height: size)
            ctx.fill(roundedPath(rect.insetBy(dx: -ol, dy: -ol), size * rf + ol), with: .color(st.outline.color))
            var clip = ctx
            clip.clip(to: roundedPath(rect, size * rf))
            clip.draw(Image(decorative: photo, scale: 1), in: rect)
            if dead { clip.fill(Path(rect), with: .color(.black.opacity(120.0 / 255.0))) }
            return
        }

        let rad = max(2, u * st.radius)
        let head = CGRect(x: c.x - u / 2, y: c.y - u / 2, width: u, height: u)
        ctx.fill(roundedPath(head.insetBy(dx: -ol, dy: -ol), rad + ol), with: .color(st.outline.color))
        ctx.fill(roundedPath(head, rad), with: .color(st.head.color))

        let fx = cos(view.face)
        let fy = sin(view.face)
        let qx = -fy
        let qy = fx
        let corner = st.radius

        func at(_ a: Double, _ b: Double) -> CGPoint {
            CGPoint(x: c.x + (fx * a + qx * b) * u, y: c.y + (fy * a + qy * b) * u)
        }
        func atInside(_ a: Double, _ b: Double) -> CGPoint {
            let x = fx * a + qx * b
            let y = fy * a + qy * b
            let lim = 0.5 - 0.035
            let r = max(corner * 0.9, 0.02)
            let core = lim - r
            let sx: Double = x >= 0 ? 1 : -1
            let sy: Double = y >= 0 ? 1 : -1
            var ax = abs(x)
            var ay = abs(y)
            let dx = ax - core
            let dy = ay - core
            if dx > 0 && dy > 0 {
                let d = hypot(dx, dy)
                if d > r {
                    ax = core + dx * r / d
                    ay = core + dy * r / d
                }
            }
            ax = min(ax, lim)
            ay = min(ay, lim)
            return CGPoint(x: c.x + sx * ax * u, y: c.y + sy * ay * u)
        }
        func polygon(_ pts: [CGPoint]) -> Path {
            var p = Path()
            p.addLines(pts)
            p.closeSubpath()
            return p
        }

        let o = view.mouth
        if o > 0.04 {
            func wedge(_ back: Double, _ frontF: Double, _ frontW: Double, _ grow: Double) -> [CGPoint] {
                let pts: [(Double, Double)] = [(back, 0.06 * grow * o), (0.18, 0.22 * grow * o), (frontF, frontW * o)]
                return pts.map { atInside($0.0, $0.1) } + pts.reversed().map { atInside($0.0, -$0.1) }
            }
            ctx.fill(polygon(wedge(-0.22, 0.50, 0.44, 1.0)), with: .color(RGB(140, 18, 32).color))
            ctx.fill(polygon(wedge(-0.15, 0.45, 0.34, 0.8)), with: .color(RGB(236, 52, 66).color))
            if o > 0.5 {
                ctx.fill(polygon([atInside(0.14, 0), atInside(0.40, 0.11 * o), atInside(0.40, -0.11 * o)]),
                         with: .color(RGB(255, 140, 150).color))
            }
        }

        let blinking = m.blinkLeft > 0 && !dead
        let eyeR = 0.16 * u
        let pupR = 0.088 * u
        let ink = RGB(32, 38, 60).color
        for side in [1.0, -1.0] {
            let e = at(-0.14, 0.285 * side)
            if blinking {
                var p = Path()
                p.move(to: CGPoint(x: e.x - qx * eyeR, y: e.y - qy * eyeR))
                p.addLine(to: CGPoint(x: e.x + qx * eyeR, y: e.y + qy * eyeR))
                ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: max(1.5, 0.05 * u), lineCap: .round))
                continue
            }
            ctx.fill(circlePath(e, eyeR + 0.022 * u), with: .color(ink))
            ctx.fill(circlePath(e, eyeR), with: .color(.white))
            if dead {
                let d = eyeR * 0.55
                var p = Path()
                p.move(to: CGPoint(x: e.x - d, y: e.y - d))
                p.addLine(to: CGPoint(x: e.x + d, y: e.y + d))
                p.move(to: CGPoint(x: e.x - d, y: e.y + d))
                p.addLine(to: CGPoint(x: e.x + d, y: e.y - d))
                ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: max(1.5, 0.045 * u), lineCap: .round))
            } else {
                let px = e.x + view.look.0 * 0.075 * u
                let py = e.y + view.look.1 * 0.075 * u
                ctx.fill(circlePath(CGPoint(x: px, y: py), pupR), with: .color(RGB(18, 22, 38).color))
                ctx.fill(circlePath(CGPoint(x: px - 0.03 * u, y: py - 0.03 * u), max(0.8, 0.028 * u)), with: .color(.white))
            }
        }
    }
}
