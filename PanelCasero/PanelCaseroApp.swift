import SwiftUI

@main
struct PanelCaseroApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: LightsStore
    @StateObject private var link: DeviceLink
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var camera: CameraManager
    @StateObject private var alarm: AlarmController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: LightsStore(settings: settings))
        let camera = CameraManager()
        let link = DeviceLink(settings: settings)
        _camera = StateObject(wrappedValue: camera)
        _link = StateObject(wrappedValue: link)
        _alarm = StateObject(wrappedValue: AlarmController(settings: settings, camera: camera, link: link))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(link)
                .environmentObject(alarm)
                .environmentObject(favorites)
                .environmentObject(camera)
                .preferredColorScheme(settings.colorScheme)
                .onAppear { setup() }
                .onChange(of: settings.motionSensitivity) { value in
                    camera.setSensitivity(value)
                }
                .onChange(of: settings.lightChangeIsMotion) { value in
                    camera.setLightChangeCountsAsMotion(value)
                }
                .onChange(of: settings.serverToken) { value in
                    StreamServer.shared.setToken(value)
                    link.kick()
                }
                .onChange(of: settings.serverURL) { _ in
                    link.kick()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                resume()
            } else {
                pause()
            }
        }
    }

    /// Arranque de la app.
    @MainActor
    private func setup() {
        // La pantalla nunca se apaga sola.
        UIApplication.shared.isIdleTimerDisabled = true
        TouchWatcher.install()

        let link = self.link
        let alarm = self.alarm
        camera.onEventsChanged = { [weak link] in
            Task { @MainActor in link?.kick() }
        }
        camera.onMotion = { [weak alarm] in
            Task { @MainActor in alarm?.motionDetected() }
        }
        link.alarmState = { [weak alarm] in alarm?.state.rawValue }
        link.onPhotoUploaded = { [weak alarm] id in alarm?.photoUploaded(id) }
        StreamServer.shared.alarmHandler = { action, completion in
            Task { @MainActor in completion(alarm.handleRemote(action)) }
        }
        camera.setSensitivity(settings.motionSensitivity)
        camera.setLightChangeCountsAsMotion(settings.lightChangeIsMotion)
        StreamServer.shared.setToken(settings.serverToken)
        resume()
    }

    @MainActor
    private func resume() {
        BrightnessController.shared.start()
        store.startPolling()
        link.start()
        StreamServer.shared.start()
        camera.start()
    }

    @MainActor
    private func pause() {
        // Al salir de la app, el iPhone recupera su brillo normal.
        BrightnessController.shared.stop()
        store.stopPolling()
        link.stop()
        StreamServer.shared.stop()
        camera.stop()
    }
}
