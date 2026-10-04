import SwiftUI

/// Ajustes. Si hay un PIN definido, piden el PIN para abrirse.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @EnvironmentObject var camera: CameraManager
    @EnvironmentObject var link: DeviceLink
    @EnvironmentObject var alarm: AlarmController
    @EnvironmentObject var weather: WeatherService
    @Environment(\.presentationMode) private var presentationMode

    @State private var unlocked = false
    @State private var testResult: String? = nil
    @State private var testing = false
    @State private var newPIN = ""
    @State private var repeatPIN = ""
    @State private var pinMessage: String? = nil

    private let sirenOptions = [0, 15, 30, 60, 120]

    var body: some View {
        NavigationView {
            Group {
                if settings.hasPIN && !unlocked {
                    gate
                } else {
                    form
                }
            }
            .navigationTitle(settings.t("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("close")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Puerta con PIN

    private var gate: some View {
        VStack {
            PINPadView(title: settings.t("settings_locked"),
                       length: settings.alarmPINLength,
                       onComplete: { pin in
                           if alarm.checkPIN(pin) {
                               unlocked = true
                               return true
                           }
                           return false
                       })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Formulario

    private var form: some View {
        Form {
            Section(header: Text(settings.t("appearance"))) {
                Picker(settings.t("appearance"), selection: $settings.appearance) {
                    Text(settings.t("dark")).tag(AppAppearance.dark)
                    Text(settings.t("light")).tag(AppAppearance.light)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text(settings.t("language"))) {
                ForEach(AppLanguage.allCases) { lang in
                    Button(action: { settings.language = lang }) {
                        HStack {
                            Text(lang.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if settings.language == lang {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            Section(header: Text(settings.t("weather"))) {
                TextField(settings.t("city"), text: $settings.weatherCity)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .onSubmit { Task { await weather.refresh() } }
                if !weather.placeName.isEmpty {
                    Text(weather.placeName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text(settings.t("alarm_section"))) {
                HStack {
                    Text("PIN")
                    Spacer()
                    Text(settings.hasPIN ? settings.t("pin_is_set") : settings.t("pin_not_set"))
                        .foregroundColor(.secondary)
                }
                SecureField(settings.t("pin_new"), text: $newPIN)
                    .keyboardType(.numberPad)
                SecureField(settings.t("pin_repeat"), text: $repeatPIN)
                    .keyboardType(.numberPad)
                Button(settings.t("pin_save")) { savePIN() }
                if let text = pinMessage {
                    Text(text)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Picker(settings.t("siren"), selection: $settings.sirenSeconds) {
                    ForEach(sirenOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? settings.t("siren_off") : "\(seconds) s").tag(seconds)
                    }
                }
            }

            Section(header: Text(settings.t("server"))) {
                TextField("192.168.1.200:8090", text: $settings.serverURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                SecureField(settings.t("token"), text: $settings.serverToken)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Button(settings.t("test_connection")) { runTest() }
                    .disabled(testing)
                if let result = testResult {
                    Text(result)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text(settings.t("lights"))) {
                ForEach(AppSettings.lightIDs, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(settings.defaultLightName(id), text: nameBinding(id))
                        Picker(settings.t("icon"), selection: iconBinding(id)) {
                            ForEach(AppSettings.iconChoices, id: \.self) { icon in
                                Image(systemName: icon).tag(icon)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section(header: Text(settings.t("camera_section"))) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(settings.t("sensitivity"))
                        Spacer()
                        Text("\(settings.motionSensitivity)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: sensitivityBinding, in: 1...10, step: 1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(settings.t("motion_now"))
                        Spacer()
                        Circle()
                            .fill(camera.motionActive ? Color.red : Color.gray.opacity(0.4))
                            .frame(width: 10, height: 10)
                    }
                    ProgressView(value: camera.motionScore)
                }
                Toggle(settings.t("light_change_motion"), isOn: $settings.lightChangeIsMotion)
                Button(settings.t("send_test_event")) {
                    camera.captureEvent(kind: "test")
                }
                .disabled(camera.state != .running)
                HStack {
                    Text(settings.t("server_link"))
                    Spacer()
                    Text(linkText)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(settings.t("events_pending"))
                    Spacer()
                    Text("\(link.pendingCount)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Acciones

    private func savePIN() {
        let pin = newPIN.trimmingCharacters(in: .whitespaces)
        let digitsOnly = pin.allSatisfy { "0123456789".contains($0) }
        guard digitsOnly, pin.count >= 4, pin.count <= 8 else {
            pinMessage = settings.t("pin_invalid")
            return
        }
        guard pin == repeatPIN else {
            pinMessage = settings.t("pin_mismatch")
            return
        }
        settings.setPIN(pin)
        newPIN = ""
        repeatPIN = ""
        pinMessage = settings.t("pin_saved")
    }

    private var linkText: String {
        switch link.serverReachable {
        case .some(true): return settings.t("link_ok")
        case .some(false): return settings.t("link_down")
        case .none: return settings.t("link_unknown")
        }
    }

    private var sensitivityBinding: Binding<Double> {
        Binding(
            get: { Double(settings.motionSensitivity) },
            set: { settings.motionSensitivity = Int($0) }
        )
    }

    private func nameBinding(_ id: String) -> Binding<String> {
        Binding(
            get: { settings.lightNames[id] ?? "" },
            set: { settings.lightNames[id] = $0 }
        )
    }

    private func iconBinding(_ id: String) -> Binding<String> {
        Binding(
            get: { settings.lightIcon(id) },
            set: { settings.lightIcons[id] = $0 }
        )
    }

    private func runTest() {
        testing = true
        testResult = nil
        Task {
            let status = await store.testConnection()
            switch status {
            case .connected: testResult = settings.t("connection_ok")
            case .unauthorized: testResult = settings.t("unauthorized")
            case .unreachable: testResult = settings.t("connection_error")
            case .notConfigured: testResult = settings.t("not_configured")
            }
            testing = false
            await store.refresh()
        }
    }
}
