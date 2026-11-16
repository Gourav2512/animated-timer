// CuteTimer — a tiny always-on-top animated timer for macOS.
// Usage:  cutetimer                 -> opens a setup card (title + minutes)
//         cutetimer 25 Deep work    -> starts a 25-minute "Deep work" timer right away
import SwiftUI
import AppKit
import Combine

// MARK: - Palette

enum Palette {
    static let plum     = Color(red: 0.36, green: 0.18, blue: 0.42)
    static let pink     = Color(red: 1.00, green: 0.74, blue: 0.83)
    static let peach    = Color(red: 1.00, green: 0.87, blue: 0.76)
    static let lavender = Color(red: 0.82, green: 0.77, blue: 1.00)
    static let hotPink  = Color(red: 1.00, green: 0.42, blue: 0.62)
    static let purple   = Color(red: 0.62, green: 0.45, blue: 1.00)
    static let alarm    = Color(red: 0.90, green: 0.22, blue: 0.38)
}

// MARK: - Model

final class TimerModel: ObservableObject {
    enum Phase { case setup, running, paused, done }

    @Published var phase: Phase = .setup
    @Published var title = ""
    @Published var minutesText = "25"
    @Published var total: TimeInterval = 1
    @Published var remaining: TimeInterval = 0
    @Published var doneAt = Date.distantPast

    private var endDate = Date()
    private var ticker: Timer?

    var progress: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }

    var timeString: String {
        let s = Int(remaining.rounded(.up))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    func startFromInputs() {
        let cleaned = minutesText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let m = Double(cleaned), m > 0 else { NSSound.beep(); return }
        start(minutes: m, title: title)
    }

    func start(minutes: Double, title t: String) {
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
        title = trimmed.isEmpty ? "Focus time" : trimmed
        minutesText = minutes == minutes.rounded() ? String(Int(minutes)) : String(minutes)
        total = minutes * 60
        remaining = total
        resume()
    }

    func resume() {
        guard remaining > 0 else { return }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func pause() {
        ticker?.invalidate()
        remaining = max(0, endDate.timeIntervalSinceNow)
        phase = .paused
    }

    func toggle() { phase == .running ? pause() : resume() }

    func addMinute() {
        if phase == .done {            // snooze
            total = 60; remaining = 60; resume(); return
        }
        total += 60
        remaining += 60
        if phase == .running { endDate.addTimeInterval(60) }
    }

    func restart() { remaining = total; resume() }

    func backToSetup() { ticker?.invalidate(); phase = .setup }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        ticker?.invalidate()
        remaining = 0
        doneAt = Date()
        phase = .done
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                NSSound(contentsOfFile: "/System/Library/Sounds/Glass.aiff", byReference: true)?.play()
            }
        }
    }
}

// MARK: - Window plumbing

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Invisible view that lets you drag the borderless window around.
struct DragArea: NSViewRepresentable {
    final class V: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> NSView { V() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Views

struct CuteBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let a = (sin(t / 2.5) + 1) / 2
            LinearGradient(colors: [Palette.pink, Palette.peach, Palette.lavender],
                           startPoint: UnitPoint(x: a, y: 0),
                           endPoint: UnitPoint(x: 1 - a, y: 1))
        }
    }
}

struct RoundButton: View {
    let symbol: String?
    let label: String?
    let help: String
    let action: () -> Void
    @State private var hover = false

    init(_ symbol: String? = nil, label: String? = nil, help: String, action: @escaping () -> Void) {
        self.symbol = symbol; self.label = label; self.help = help; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
                else { Text(label ?? "").font(.system(size: 11, weight: .heavy, design: .rounded)) }
            }
            .foregroundColor(Palette.plum)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(hover ? 0.95 : 0.65)))
            .scaleEffect(hover ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct SetupView: View {
    @ObservedObject var model: TimerModel
    @FocusState private var focus: Field?
    enum Field { case title, minutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("⏰").font(.system(size: 20))
                Text("New cute timer")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.plum)
                Spacer()
                RoundButton("xmark", help: "Close") { NSApp.terminate(nil) }
            }

            TextField("What are we doing? ✨", text: $model.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.75)))
                .focused($focus, equals: .title)
                .onSubmit { focus = .minutes }

            HStack(spacing: 6) {
                TextField("25", text: $model.minutesText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(width: 44)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.75)))
                    .focused($focus, equals: .minutes)
                    .onSubmit { model.startFromInputs() }
                Text("min").font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.plum.opacity(0.8))
                Spacer(minLength: 4)
                ForEach([5, 15, 25, 45], id: \.self) { m in
                    Button { model.minutesText = "\(m)" } label: {
                        Text("\(m)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.plum)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(model.minutesText == "\(m)" ? 0.95 : 0.5)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: model.startFromInputs) {
                Text("Start  ▶︎")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LinearGradient(colors: [Palette.hotPink, Palette.purple],
                                                              startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = .title } }
    }
}

struct RunningView: View {
    @ObservedObject var model: TimerModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            content(t: ctx.date.timeIntervalSinceReferenceDate, now: ctx.date)
        }
    }

    @ViewBuilder
    private func content(t: Double, now: Date) -> some View {
        let done = model.phase == .done
        let paused = model.phase == .paused
        let urgent = model.phase == .running && model.remaining <= 10
        let sinceDone = now.timeIntervalSince(model.doneAt)

        // little mascot animation
        let mascot = done ? "😻" : paused ? "😴" : urgent ? "🙀" : "🐱"
        let hop = done ? -abs(sin(t * 6)) * 6 : paused ? 0 : -abs(sin(t * 3)) * 4
        let tilt = done ? sin(t * 12) * 12 : paused ? 0 : sin(t * 3) * 7
        let breathe = paused ? 1 + sin(t * 1.6) * 0.06 : 1
        let pulse = urgent ? 1 + max(0, sin(t * .pi * 2)) * 0.08 : 1
        // happy shake when the timer finishes
        let shake = done && sinceDone < 1.6 ? sin(sinceDone * 45) * 5 * (1 - sinceDone / 1.6) : 0

        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.6), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: done ? 1 : model.progress)
                    .stroke(AngularGradient(colors: [Palette.hotPink, Palette.purple, Palette.hotPink], center: .center),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: model.progress)
                Text(mascot)
                    .font(.system(size: 24))
                    .scaleEffect(breathe)
                    .rotationEffect(.degrees(tilt))
                    .offset(y: hop)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 0) {
                Text(model.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.plum.opacity(0.75))
                    .lineLimit(1)
                Text(done ? "Time's up! 🎉" : model.timeString)
                    .font(.system(size: done ? 21 : 27, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(urgent ? Palette.alarm : Palette.plum)
                    .scaleEffect(pulse, anchor: .leading)
                    .opacity(paused ? 0.55 + 0.45 * (sin(t * 3) + 1) / 2 : 1)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                if done {
                    RoundButton("arrow.counterclockwise", help: "Restart") { model.restart() }
                    RoundButton(label: "+1", help: "Snooze 1 minute") { model.addMinute() }
                } else {
                    RoundButton(paused ? "play.fill" : "pause.fill", help: paused ? "Resume" : "Pause") { model.toggle() }
                    RoundButton(label: "+1", help: "Add a minute") { model.addMinute() }
                }
                RoundButton("pencil", help: "New timer") { model.backToSetup() }
                RoundButton("xmark", help: "Close") { NSApp.terminate(nil) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(width: 340)
        .offset(x: shake)
        .overlay(done ? Sparkles(t: t).allowsHitTesting(false) : nil)
    }
}

struct Sparkles: View {
    let t: Double
    private let glyphs = ["✨", "💖", "⭐️", "🌸", "💫", "🎀", "✨", "💕", "⭐️", "🌷"]
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<glyphs.count, id: \.self) { i in
                let phase = (t * 0.45 + Double(i) * 0.137).truncatingRemainder(dividingBy: 1)
                let x = (Double(i) + 0.5) / Double(glyphs.count) * geo.size.width + sin(t * 2 + Double(i)) * 8
                let y = geo.size.height * (1.1 - phase * 1.2)
                Text(glyphs[i])
                    .font(.system(size: 11))
                    .opacity(sin(phase * .pi) * 0.9)
                    .position(x: x, y: y)
            }
        }
    }
}

struct RootView: View {
    @ObservedObject var model: TimerModel
    var body: some View {
        Group {
            if model.phase == .setup { SetupView(model: model) }
            else { RunningView(model: model) }
        }
        .background(ZStack { CuteBackground(); DragArea() })
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.75), lineWidth: 1.5))
        .fixedSize()
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = TimerModel()
    var panel: FloatingPanel!
    var hosting: NSHostingView<RootView>!
    var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        parseArgs()

        hosting = NSHostingView(rootView: RootView(model: model))
        let size = hosting.fittingSize
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                              backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar                      // above normal & floating windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            // stagger a little if several timers are open
            let stagger = CGFloat(NSRunningApplication.runningApplications(
                withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count - 1) * 18
            panel.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2 + stagger,
                                         y: vf.maxY - size.height - 8 - stagger))
        }
        panel.orderFrontRegardless()
        focusIfSetup()

        model.$phase.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.resize() }
        }.store(in: &bag)
    }

    private func parseArgs() {
        var args = CommandLine.arguments.dropFirst().filter { !($0.hasPrefix("-") && Double($0) == nil) }
        if let i = args.firstIndex(where: { Double($0.replacingOccurrences(of: ",", with: ".")) != nil }),
           let m = Double(args[i].replacingOccurrences(of: ",", with: ".")), m > 0 {
            args.remove(at: i)
            model.start(minutes: m, title: args.joined(separator: " "))
        } else if !args.isEmpty {
            model.title = args.joined(separator: " ")
        }
    }

    private func resize() {
        hosting.layoutSubtreeIfNeeded()
        let s = hosting.fittingSize
        var f = panel.frame
        let top = f.maxY, cx = f.midX
        f.size = s
        f.origin = NSPoint(x: cx - s.width / 2, y: top - s.height)
        panel.setFrame(f, display: true, animate: true)
        focusIfSetup()
    }

    private func focusIfSetup() {
        guard model.phase == .setup else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Snapshot mode (for previews):  CuteTimer --snapshot /path/prefix

@MainActor
func renderSnapshots(prefix: String) {
    func save<V: View>(_ v: V, _ name: String) {
        let r = ImageRenderer(content: v)
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
    }
    let setup = TimerModel(); setup.title = "Write blog post"
    save(RootView(model: setup), "setup")
    let run = TimerModel(); run.start(minutes: 25, title: "Deep work 🍵"); run.remaining = 25 * 60 * 0.62
    save(RootView(model: run), "running")
    let done = TimerModel(); done.start(minutes: 5, title: "Tea break"); done.phase = .done; done.remaining = 0
    save(RootView(model: done), "done")
}

@main
struct CuteTimerMain {
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            _ = NSApplication.shared
            MainActor.assumeIsolated { renderSnapshots(prefix: args[i + 1]) }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        _ = delegate
    }
}
