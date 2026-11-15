import SwiftUI

extension Theme {
    func tone(_ t: Tone) -> Color {
        switch t {
        case .text: return text.color
        case .muted: return muted.color
        case .accent: return accent.color
        }
    }
}

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        let th = model.cfg.theme
        GeometryReader { geo in
            let lay = BoardLayout(size: geo.size, cols: model.dims.x, rows: model.dims.y)
            let ui = clamp(min(geo.size.width / 900, geo.size.height / 720), 0.6, 1.4)
            ZStack {
                TimelineView(.animation) { timeline in
                    let frameDate = timeline.date
                    Canvas { ctx, size in
                        _ = frameDate
                        Renderer(m: model).draw(ctx, size)
                    }
                }
                if let card = model.card {
                    StateCardView(card: card, theme: th, ui: ui)
                        .modifier(Bobbing(active: card.anchor == .idle, amount: 3 * ui))
                        .position(cardPosition(card.anchor, lay, ui))
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .animation(.smooth(duration: 0.25), value: model.card)
        }
        .background {
            LinearGradient(colors: [th.window.color, th.window2.color], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .overlay { OverlayLayer(model: model) }
        .overlay(alignment: .bottom) {
            if let toast = model.toast, !model.settingsOpen {
                Text(toast)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(th.text.color)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .liquidGlass(Capsule(), tint: th.panel.color(0.3))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: model.toast)
        .toolbar { toolbarContent }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar(removing: .title)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.settingsOpen = false
            model.pendingDrop = url
            return true
        }
        .onAppear { model.start() }
    }

    private func cardPosition(_ anchor: CardAnchor, _ lay: BoardLayout, _ ui: Double) -> CGPoint {
        let b = lay.board
        switch anchor {
        case .center: return CGPoint(x: b.midX, y: b.midY)
        case .upper: return CGPoint(x: b.midX, y: b.minY + b.height * 0.2)
        case .idle: return CGPoint(x: b.midX, y: b.maxY - b.height * 0.17)
        case .top: return CGPoint(x: b.midX, y: b.minY + 46 * ui)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HUDView(model: model)
        }
        ToolbarItem(placement: .principal) {
            Text(model.hud.info)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .fixedSize()
                .padding(.horizontal, 14)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.openMPMenu()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                    Text(model.hud.live ? "VS" : "2P")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(model.hud.live ? model.cfg.theme.accent.color : Color.primary)
            }
            .help("Multiplayer (M)")
            Button {
                model.toggleSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .rotationEffect(.degrees(model.settingsOpen ? 75 : 0))
                    .animation(.spring(duration: 0.4, bounce: 0.3), value: model.settingsOpen)
            }
            .help("Settings (Esc)")
        }
    }
}

struct Bobbing: ViewModifier {
    let active: Bool
    let amount: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation) { tl in
                content.offset(y: sin(tl.date.timeIntervalSinceReferenceDate * 3) * amount)
            }
        } else {
            content
        }
    }
}

struct StateCardView: View {
    let card: BoardCard
    let theme: Theme
    let ui: Double

    var body: some View {
        VStack(spacing: 6 * ui) {
            ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                Text(line.text)
                    .font(.system(size: line.size * ui, weight: line.size >= 30 ? .heavy : .semibold, design: .rounded))
                    .foregroundStyle(theme.tone(line.tone))
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .fixedSize()
            }
        }
        .padding(.horizontal, 24 * ui)
        .padding(.vertical, 18 * ui)
        .liquidGlass(RoundedRectangle(cornerRadius: 22 * ui, style: .continuous), tint: theme.panel.color(0.35))
    }
}

struct FruitIcon: View {
    let kind: String
    let photo: CGImage?
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let rect = CGRect(origin: .zero, size: sz)
            if let photo {
                drawPhotoFruit(ctx, photo, in: rect)
            } else {
                drawFruit(ctx, kind, in: rect)
            }
        }
        .frame(width: size, height: size)
    }
}

struct StyleChip: View {
    let style: SnakeStyle
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(style.body.color)
            .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).strokeBorder(style.outline.color, lineWidth: 2))
            .frame(width: size, height: size)
    }
}

struct TeleportDots: View {
    let left: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<APPLE_TELEPORTS, id: \.self) { i in
                Circle()
                    .fill(i < left ? accent : Color.white.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
    }
}

struct HUDView: View {
    let model: AppModel

    var body: some View {
        let hud = model.hud
        let th = model.cfg.theme
        let photo = model.fruitPhotoOn() ? model.photos["fruit_photo"] : nil
        let _ = model.photoVer
        HStack(spacing: 10) {
            if hud.solo {
                HStack(spacing: 5) {
                    FruitIcon(kind: model.cfg["fruit"], photo: photo, size: 18)
                    Text("\(hud.score)")
                        .contentTransition(.numericText(value: Double(hud.score)))
                }
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.2))
                    Text("\(hud.best)")
                        .contentTransition(.numericText(value: Double(hud.best)))
                }
                if hud.showTeleports {
                    HStack(spacing: 5) {
                        Text("R").foregroundStyle(.secondary)
                        TeleportDots(left: hud.teleports, accent: th.accent.color)
                    }
                }
            } else {
                ForEach(hud.entries) { e in
                    HStack(spacing: 5) {
                        if e.isApple {
                            FruitIcon(kind: model.cfg["fruit"], photo: photo, size: 18)
                            Text(e.text)
                            TeleportDots(left: e.teleports, accent: th.accent.color)
                        } else {
                            StyleChip(style: model.style(e.style), size: 14)
                            Text(e.text)
                                .foregroundStyle(e.alive ? Color.primary : Color.secondary)
                        }
                    }
                }
                if let t = hud.timeLeft {
                    Text("\(t)s")
                        .foregroundStyle(th.accent.color)
                        .contentTransition(.numericText(value: Double(t)))
                }
            }
        }
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 8)
        .animation(.snappy, value: hud)
    }
}

struct OverlayLayer: View {
    @Bindable var model: AppModel

    var body: some View {
        let anyOpen = model.settingsOpen || model.mpScreen != nil || model.pendingDrop != nil
        GeometryReader { geo in
            ZStack {
                if anyOpen {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if model.settingsOpen { model.settingsOpen = false }
                        }
                        .transition(.opacity)
                }
                if model.pendingDrop != nil {
                    DropCard(model: model)
                        .scaleEffect(fit(geo.size, CGSize(width: 520, height: 260)))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if model.mpScreen != nil {
                    MultiplayerCard(model: model)
                        .scaleEffect(fit(geo.size, CGSize(width: 540, height: 480)))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if model.settingsOpen {
                    SettingsPanel(model: model)
                        .scaleEffect(fit(geo.size, CGSize(width: 540, height: 680)))
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(duration: 0.35, bounce: 0.18), value: model.settingsOpen)
        .animation(.spring(duration: 0.35, bounce: 0.18), value: model.mpScreen)
        .animation(.spring(duration: 0.35, bounce: 0.18), value: model.pendingDrop)
    }

    private func fit(_ size: CGSize, _ need: CGSize) -> CGFloat {
        min(1, (size.height - 16) / need.height, (size.width - 20) / need.width)
    }
}

struct SettingsPanel: View {
    @Bindable var model: AppModel
    @Namespace private var ns

    var body: some View {
        let th = model.cfg.theme
        VStack(spacing: 0) {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.bottom, 14)
            GlassGroup(spacing: 8) {
                VStack(spacing: 2) {
                    ForEach(Array(OPTIONS.enumerated()), id: \.offset) { i, opt in
                        row(i, opt, th)
                    }
                }
            }
            .animation(.spring(duration: 0.28, bounce: 0.2), value: model.settingsSel)
            Divider().padding(.vertical, 12)
            Text(footer)
                .font(.system(size: 13))
                .foregroundStyle(th.muted.color)
                .multilineTextAlignment(.center)
                .frame(height: 52, alignment: .top)
                .padding(.horizontal, 16)
            Text("↑ ↓ select     ← → change     esc close")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
            Button {
                model.settingsOpen = false
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 120)
            }
            .controlSize(.large)
            .liquidButton(prominent: true)
            .tint(th.accent.color)
            .keyboardShortcut(.defaultAction)
        }
        .padding(22)
        .frame(width: 520)
        .liquidGlass(RoundedRectangle(cornerRadius: 32, style: .continuous), tint: th.panel.color(0.25))
    }

    private var footer: String {
        if let note = model.settingsNote { return note }
        let key = OPTIONS[model.settingsSel].key
        if PHOTO_KEYS.contains(key) {
            let have = model.photos[key] != nil ? "A photo is saved." : "No photo yet."
            return "\(PHOTO_LABELS[key] ?? ""): \(have) Drag an image file onto the window to set it."
        }
        let mode = model.shownValue("mode")
        return "\(mode): \(MODE_INFO[mode] ?? "")"
    }

    @ViewBuilder
    private func row(_ i: Int, _ opt: OptionDef, _ th: Theme) -> some View {
        let selected = model.settingsSel == i
        let value = model.shownValue(opt.key)
        HStack(spacing: 8) {
            Text(opt.label)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            OptionPreview(model: model, key: opt.key, value: value)
                .frame(width: 60, height: 30)
            Button { model.change(i, -1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
            }
            .liquidButton()
            .buttonBorderShape(.circle)
            .controlSize(.small)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(th.accent.color)
                .frame(width: 118)
                .contentTransition(.numericText())
                .contentShape(Rectangle())
                .onTapGesture { model.change(i, 1) }
            Button { model.change(i, 1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
            }
            .liquidButton()
            .buttonBorderShape(.circle)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(th.accent.color.opacity(0.85), lineWidth: 1.5))
                    .matchedGeometryEffect(id: "selection", in: ns)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { model.settingsSel = i }
        }
        .onTapGesture { model.settingsSel = i }
        .animation(.snappy(duration: 0.2), value: value)
    }
}

struct OptionPreview: View {
    let model: AppModel
    let key: String
    let value: String

    var body: some View {
        let _ = model.photoVer
        switch key {
        case "fruit":
            FruitIcon(kind: value, photo: nil, size: 28)
        case "snake":
            let st = model.style(value)
            HStack(spacing: 2) {
                StyleChip(style: st, size: 12)
                StyleChip(style: st, size: 12)
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(st.head.color)
                    .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous).strokeBorder(st.outline.color, lineWidth: 2))
                    .frame(width: 14, height: 14)
            }
        case "theme":
            let t = THEMES[value] ?? model.cfg.theme
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(t.boardA.color)
                    Rectangle().fill(t.boardB.color)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(t.boardB.color)
                    Rectangle().fill(t.boardA.color)
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(t.frame.color, lineWidth: 2))
        case "bg_photo", "head_photo", "fruit_photo":
            if let img = model.photos[key] {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
            } else {
                Image(systemName: "photo.badge.plus")
                    .foregroundStyle(.tertiary)
            }
        default:
            Color.clear
        }
    }
}

struct DropCard: View {
    @Bindable var model: AppModel

    var body: some View {
        let th = model.cfg.theme
        VStack(spacing: 14) {
            Text("Use this photo as:")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(model.pendingDrop?.lastPathComponent ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 420)
            GlassGroup(spacing: 12) {
                HStack(spacing: 12) {
                    choice("bg_photo", "Background", "photo.fill", "B", th)
                    choice("head_photo", "Head", "person.crop.square.fill", "H", th)
                    choice("fruit_photo", "Fruit", "circle.circle.fill", "F", th)
                }
            }
            Button("Cancel") { model.pendingDrop = nil }
                .liquidButton()
                .keyboardShortcut(.cancelAction)
        }
        .padding(26)
        .liquidGlass(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: th.panel.color(0.25))
    }

    private func choice(_ kind: String, _ name: String, _ icon: String, _ key: String, _ th: Theme) -> some View {
        Button {
            model.chooseDrop(kind)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22))
                Text("\(name) (\(key))").font(.system(size: 13, weight: .semibold))
            }
            .frame(width: 124, height: 64)
        }
        .liquidButton(prominent: true)
        .tint(th.accent.color.opacity(0.85))
    }
}

struct MultiplayerCard: View {
    @Bindable var model: AppModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let th = model.cfg.theme
        VStack(spacing: 12) {
            switch model.mpScreen {
            case .menu: menu(th)
            case .hostWait: hostWait(th)
            case .join: join(th)
            case nil: EmptyView()
            }
        }
        .padding(26)
        .frame(width: 500)
        .liquidGlass(RoundedRectangle(cornerRadius: 32, style: .continuous), tint: th.panel.color(0.25))
    }

    private func title(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 26, weight: .bold, design: .rounded))
    }

    private func wide(_ label: String, _ icon: String, prominent: Bool, _ th: Theme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .controlSize(.large)
        .liquidButton(prominent: prominent)
        .tint(prominent ? th.accent.color.opacity(0.85) : nil)
    }

    @ViewBuilder
    private func message(_ th: Theme) -> some View {
        if !model.mpMsg.isEmpty {
            Text(model.mpMsg)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(th.accent.color)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func menu(_ th: Theme) -> some View {
        let appleMode = model.cfg["mode"] == "Apple"
        title("Multiplayer", "person.2.fill")
        Text("Wi-Fi (up to 4 players) or one Mac (2 players)")
            .foregroundStyle(th.muted.color)
        Text(appleMode ? "Apple mode: one of you is the apple, the others are the snakes"
             : "Tip: Game Mode Apple = real apple vs real snakes")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        if model.role == .solo {
            GlassGroup(spacing: 10) {
                VStack(spacing: 10) {
                    wide("Host a game on Wi-Fi   (H)", "wifi", prominent: true, th) { model.beginHosting() }
                    wide("Join a game on Wi-Fi   (J)", "arrow.down.circle", prominent: true, th) { model.beginJoin() }
                    wide("Play on this Mac   (L)", "keyboard", prominent: true, th) { model.startLocal() }
                    wide("Close", "xmark", prominent: false, th) { model.closeMPScreen() }
                }
            }
            .padding(.top, 6)
        } else {
            let who = ["host": "the host", "client": "a guest", "local": "playing on this Mac"][model.role.rawValue] ?? ""
            Text("You are \(who)")
                .font(.system(size: 18, weight: .semibold))
                .padding(.vertical, 8)
            GlassGroup(spacing: 10) {
                VStack(spacing: 10) {
                    wide("Leave this game", "rectangle.portrait.and.arrow.right", prominent: true, th) {
                        model.leaveMultiplayer("Left multiplayer")
                    }
                    wide("Close", "xmark", prominent: false, th) { model.closeMPScreen() }
                }
            }
        }
        message(th)
    }

    @ViewBuilder
    private func hostWait(_ th: Theme) -> some View {
        let joined = model.lobby.filter { $0.style != nil }.count
        title("Hosting", "antenna.radiowaves.left.and.right")
        Text("Friends open Multiplayer, pick Join and type:")
            .foregroundStyle(th.muted.color)
        Text(model.myIP)
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .foregroundStyle(th.accent.color)
            .textSelection(.enabled)
        Text("(port \(model.hostPort), or they pick this game from the list)")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.lobby) { entry in
                HStack(spacing: 10) {
                    if let s = entry.style {
                        StyleChip(style: model.style(s), size: 16)
                    } else {
                        ProgressView().controlSize(.mini).frame(width: 16, height: 16)
                    }
                    Text(entry.name)
                        .font(.system(size: 15, weight: entry.style != nil ? .semibold : .regular))
                        .foregroundStyle(entry.style != nil ? th.text.color : th.muted.color)
                }
            }
        }
        .padding(.vertical, 6)
        if model.cfg["mode"] == "Apple" {
            Button("First apple: Player \(model.firstApple % max(1, joined) + 1)   (change: A)") {
                model.cycleFirstApple()
            }
            .liquidButton()
        }
        message(th)
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                wide(joined > 1 ? "Start game (\(joined) players)" : "Start (need 2+ players)", "play.fill",
                     prominent: joined > 1, th) { model.startMatch() }
                wide("Cancel", "xmark", prominent: false, th) { model.backToMenu() }
                    .frame(width: 150)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func join(_ th: Theme) -> some View {
        title("Join a game", "arrow.down.circle")
        Text("Type the host's IP address and press Enter")
            .foregroundStyle(th.muted.color)
        TextField("192.168.0.10", text: $model.joinText)
            .textFieldStyle(.plain)
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .focused($fieldFocused)
            .onSubmit { model.connectTo(model.joinText) }
            .onChange(of: model.joinText) { _, newValue in
                let filtered = String(newValue.filter { $0.isLetter || $0.isNumber || ".:-".contains($0) }.prefix(40))
                if filtered != newValue { model.joinText = filtered }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(width: 340)
            .liquidGlass(Capsule())
            .onAppear { fieldFocused = true }
        if model.foundHosts.isEmpty {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Looking for games on this Wi-Fi...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } else {
            GlassGroup(spacing: 8) {
                VStack(spacing: 8) {
                    ForEach(model.foundHosts.prefix(3), id: \.ip) { host in
                        wide("\(host.ip)   (\(host.count)/\(MAX_PLAYERS) players)", "gamecontroller.fill", prominent: false, th) {
                            model.connectFound(host)
                        }
                    }
                }
            }
        }
        message(th)
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                wide("Connect", "link", prominent: true, th) { model.connectTo(model.joinText) }
                wide("Back", "chevron.left", prominent: false, th) { model.backToMenu() }
            }
        }
        .padding(.top, 4)
    }
}
