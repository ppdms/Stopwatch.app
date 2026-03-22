import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var stopwatchEpoch: Date?
    private var targetDate: Date?
    private var dayProgressEnabled = false
    private var stopwatchEnabled = false
    private var dateComparisonEnabled = false
    private var daysOnlyDateComparison = false
    private var ymdDateComparison = false
    private var yearProgressEnabled = false
    private var busStatusEnabled = false
    private var lastBusCheck: String?
    private var displayTimer: Timer?
    private var busTimer: Timer?
    private var datePickerWindowController: DatePickerWindowController?

    private let configFile = NSHomeDirectory() + "/.stopwatch_state.json"

    // MARK: - Menu Items (stored for title updates)
    private var stopwatchMenuItem: NSMenuItem!
    private var dateComparisonMenuItem: NSMenuItem!
    private var dayProgressMenuItem: NSMenuItem!
    private var yearProgressMenuItem: NSMenuItem!
    private var busStatusMenuItem: NSMenuItem!
    private var dateFormatMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        loadState()
        buildMenu()

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        displayTimer?.tolerance = 0.1
        RunLoop.main.add(displayTimer!, forMode: .common)

        busTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateBusTime()
        }
        busTimer?.tolerance = 5

        updateDisplay()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        stopwatchMenuItem = NSMenuItem(
            title: stopwatchEnabled ? "Disable Stopwatch" : "Enable Stopwatch",
            action: #selector(toggleStopwatch),
            keyEquivalent: ""
        )
        stopwatchMenuItem.target = self
        menu.addItem(stopwatchMenuItem)

        dateComparisonMenuItem = NSMenuItem(
            title: dateComparisonEnabled ? "Disable Date Comparison" : "Enable Date Comparison",
            action: #selector(toggleDateComparison),
            keyEquivalent: ""
        )
        dateComparisonMenuItem.target = self
        menu.addItem(dateComparisonMenuItem)

        dayProgressMenuItem = NSMenuItem(
            title: dayProgressEnabled ? "Disable Day Progress" : "Enable Day Progress",
            action: #selector(toggleDayProgress),
            keyEquivalent: ""
        )
        dayProgressMenuItem.target = self
        menu.addItem(dayProgressMenuItem)

        yearProgressMenuItem = NSMenuItem(
            title: yearProgressEnabled ? "Disable Year Progress" : "Enable Year Progress",
            action: #selector(toggleYearProgress),
            keyEquivalent: ""
        )
        yearProgressMenuItem.target = self
        menu.addItem(yearProgressMenuItem)

        busStatusMenuItem = NSMenuItem(
            title: busStatusEnabled ? "Disable Bus Status" : "Enable Bus Status",
            action: #selector(toggleBusStatus),
            keyEquivalent: ""
        )
        busStatusMenuItem.target = self
        menu.addItem(busStatusMenuItem)

        dateFormatMenuItem = NSMenuItem(
            title: dateFormatTitle(),
            action: #selector(toggleDateComparisonFormat),
            keyEquivalent: ""
        )
        dateFormatMenuItem.target = self
        menu.addItem(dateFormatMenuItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func dateFormatTitle() -> String {
        if daysOnlyDateComparison {
            return "Toggle Date Comparison Format (D)"
        } else if ymdDateComparison {
            return "Toggle Date Comparison Format (YMD)"
        } else {
            return "Toggle Date Comparison Format (YMDHMS)"
        }
    }

    // MARK: - Actions

    @objc private func toggleStopwatch() {
        if stopwatchEnabled {
            stopwatchEnabled = false
            stopwatchEpoch = nil
            stopwatchMenuItem.title = "Enable Stopwatch"
        } else {
            stopwatchEnabled = true
            stopwatchEpoch = Date()
            stopwatchMenuItem.title = "Disable Stopwatch"
        }
        saveState()
    }

    @objc private func toggleDayProgress() {
        dayProgressEnabled.toggle()
        dayProgressMenuItem.title = dayProgressEnabled ? "Disable Day Progress" : "Enable Day Progress"
        saveState()
    }

    @objc private func toggleDateComparison() {
        if dateComparisonEnabled {
            dateComparisonEnabled = false
            dateComparisonMenuItem.title = "Enable Date Comparison"
        } else {
            dateComparisonEnabled = true
            dateComparisonMenuItem.title = "Disable Date Comparison"
            showDatePicker()
        }
        saveState()
    }

    @objc private func toggleDateComparisonFormat() {
        if daysOnlyDateComparison {
            daysOnlyDateComparison = false
            ymdDateComparison = true
        } else if ymdDateComparison {
            ymdDateComparison = false
        } else {
            daysOnlyDateComparison = true
        }
        dateFormatMenuItem.title = dateFormatTitle()
        saveState()
    }

    @objc private func toggleYearProgress() {
        yearProgressEnabled.toggle()
        yearProgressMenuItem.title = yearProgressEnabled ? "Disable Year Progress" : "Enable Year Progress"
        saveState()
    }

    @objc private func toggleBusStatus() {
        busStatusEnabled.toggle()
        busStatusMenuItem.title = busStatusEnabled ? "Disable Bus Status" : "Enable Bus Status"
        if busStatusEnabled {
            updateBusTime()
        }
        saveState()
    }

    // MARK: - Date Picker

    private func showDatePicker() {
        if datePickerWindowController == nil {
            datePickerWindowController = DatePickerWindowController { [weak self] date in
                self?.targetDate = date
                self?.saveState()
            }
        }
        datePickerWindowController?.showWindow()
    }

    // MARK: - Display

    private func updateDisplay() {
        var parts: [String] = []

        if stopwatchEnabled {
            if let epoch = stopwatchEpoch {
                let diff = Date().timeIntervalSince(epoch)
                if diff >= 86400 {
                    stopwatchEpoch = nil
                    stopwatchEnabled = false
                    saveState()
                } else {
                    let total = Int(diff)
                    let h = total / 3600
                    let m = (total % 3600) / 60
                    let s = total % 60
                    if h > 0 {
                        parts.append(String(format: "⏱️ %02d:%02d:%02d", h, m, s))
                    } else {
                        parts.append(String(format: "⏱️ %02d:%02d", m, s))
                    }
                }
            } else {
                stopwatchEpoch = nil
                stopwatchEnabled = false
                saveState()
            }
        }

        if dateComparisonEnabled, let target = targetDate {
            let now = Date()
            let calendar = Calendar.current

            if daysOnlyDateComparison {
                let days = abs(calendar.dateComponents([.day], from: now, to: target).day ?? 0)
                parts.append("🎯 \(days)D")
            } else {
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now, to: target)
                var duration = ""
                let years = abs(components.year ?? 0)
                let months = abs(components.month ?? 0)
                let days = abs(components.day ?? 0)
                let hours = abs(components.hour ?? 0)
                let minutes = abs(components.minute ?? 0)
                let seconds = abs(components.second ?? 0)

                if years != 0 { duration += "\(years)Y " }
                if months != 0 { duration += "\(months)M " }
                if days != 0 { duration += "\(days)D" }

                if !ymdDateComparison {
                    let timePart = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                    duration += duration.isEmpty ? timePart : " \(timePart)"
                }

                if !duration.isEmpty {
                    parts.append("🎯 \(duration)")
                }
            }
        }

        if dayProgressEnabled {
            let now = Date()
            let calendar = Calendar.current
            let h = calendar.component(.hour, from: now)
            let m = calendar.component(.minute, from: now)
            let s = calendar.component(.second, from: now)
            let seconds = h * 3600 + m * 60 + s

            if seconds >= 22 * 3600 || seconds < 6 * 3600 {
                parts.append("😴")
            } else {
                let percentage = Double(seconds - 6 * 3600) / Double(16 * 3600) * 100
                parts.append(String(format: "⏳ %.2f%%", percentage))
            }
        }

        if yearProgressEnabled {
            let now = Date()
            let calendar = Calendar.current
            let year = calendar.component(.year, from: now)
            let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
            let progress = now.timeIntervalSince(startOfYear) / endOfYear.timeIntervalSince(startOfYear) * 100
            parts.append(String(format: "📅 %.1f%%", progress))
        }

        if busStatusEnabled, let busTime = lastBusCheck {
            parts.append("🚌 \(busTime)")
        }

        let text = parts.isEmpty ? "⏱️" : parts.joined(separator: " | ")
        setMonospaceTitle(text)
    }

    private func setMonospaceTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: 0
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: - Bus Status

    private func updateBusTime() {
        guard busStatusEnabled else { return }
        let url = URL(string: "http://telematics.oasa.gr/api/?act=getStopArrivals&p1=380042")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = json.first,
                  let btime = first["btime2"] as? String else {
                return
            }
            DispatchQueue.main.async {
                self?.lastBusCheck = btime
            }
        }.resume()
    }

    // MARK: - Persistence

    private func loadState() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configFile)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        dateComparisonEnabled = dict["date_comparison_enabled"] as? Bool ?? false
        dayProgressEnabled = dict["day_progress_enabled"] as? Bool ?? false
        stopwatchEnabled = dict["stopwatch_enabled"] as? Bool ?? false
        daysOnlyDateComparison = dict["days_only_date_comparison"] as? Bool ?? false
        ymdDateComparison = dict["YMD_date_comparison"] as? Bool ?? false
        yearProgressEnabled = dict["year_progress_enabled"] as? Bool ?? false
        busStatusEnabled = dict["bus_status_enabled"] as? Bool ?? false

        if let iso = dict["stopwatch_epoch"] as? String {
            stopwatchEpoch = ISO8601DateFormatter().date(from: iso)
                ?? DateFormatter.iso8601Local.date(from: iso)
        }
        if let iso = dict["target_date"] as? String {
            targetDate = ISO8601DateFormatter().date(from: iso)
                ?? DateFormatter.iso8601Local.date(from: iso)
        }
    }

    private func saveState() {
        var dict: [String: Any] = [
            "date_comparison_enabled": dateComparisonEnabled,
            "day_progress_enabled": dayProgressEnabled,
            "stopwatch_enabled": stopwatchEnabled,
            "days_only_date_comparison": daysOnlyDateComparison,
            "YMD_date_comparison": ymdDateComparison,
            "year_progress_enabled": yearProgressEnabled,
            "bus_status_enabled": busStatusEnabled
        ]
        if let epoch = stopwatchEpoch {
            dict["stopwatch_epoch"] = DateFormatter.iso8601Local.string(from: epoch)
        }
        if let target = targetDate {
            dict["target_date"] = DateFormatter.iso8601Local.string(from: target)
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: configFile))
        }
    }
}

// MARK: - DateFormatter Helper

extension DateFormatter {
    static let iso8601Local: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Date Picker Window

class DatePickerWindowController {
    private var window: NSWindow!
    private var datePicker: NSDatePicker!
    private let callback: (Date) -> Void

    init(callback: @escaping (Date) -> Void) {
        self.callback = callback
        setupWindow()
    }

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSMakeRect(0, 0, 350, 250),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Target Date"
        window.center()

        datePicker = NSDatePicker(frame: NSMakeRect(25, 70, 300, 150))
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
        datePicker.isBezeled = true
        datePicker.drawsBackground = true
        datePicker.alignment = .center
        datePicker.dateValue = Date()
        window.contentView?.addSubview(datePicker)

        let button = NSButton(frame: NSMakeRect(125, 20, 100, 30))
        button.title = "Set Time"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(buttonClicked)
        window.contentView?.addSubview(button)
    }

    func showWindow() {
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func buttonClicked() {
        callback(datePicker.dateValue)
        window.orderOut(nil)
    }
}
