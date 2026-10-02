import SwiftUI

/// Ajustes. En la fase de la alarma se protegerán con el PIN.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var testResult: String? = nil
    @State private var testing = false

    var body: some View {
        NavigationView {
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

                Section(header: Text(settings.t("test_section"))) {
                    Button(settings.t("simulate_motion")) {
                        BrightnessController.shared.motionDetected()
                    }
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
