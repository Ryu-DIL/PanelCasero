import SwiftUI

@main
struct PanelCaseroApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: LightsStore
    @StateObject private var link: DeviceLink
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var camera: CameraManager
    @StateObject private var alarm: AlarmController
    @StateObject private var weather: WeatherService
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Theme.applyAppearance()
        let settings = AppSettings()
        OrientationLock.apply(settings.orientationMode)
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: LightsStore(settings: settings))
        let camera = CameraManager()
        let link = DeviceLink(settings: settings)
        _camera = StateObject(wrappedValue: camera)
        _link = StateObject(wrappedValue: link)
        _alarm = StateObject(wrappedValue: AlarmController(settings: settings, camera: camera, link: link))
        _weather = StateObject(wrappedValue: WeatherService(settings: settings))
    }

    private var environment: AppEnvironment {
        AppEnvironment(settings: settings, store: store, link: link, alarm: alarm,
                       weather: weather, favorites: favorites, camera: camera)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(env: environment)
                .injecting(environment)
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
                .onChange(of: settings.orientationMode) { mode in
                    OrientationLock.apply(mode)
                }
                .onChange(of: settings.idleDim) { value in
                    BrightnessController.shared.idleOverlay = value
                }
        }
        .onChange(of: scenePhase) { phase in
            // "inactive" ocurre con avisos del sistema o al abrir el centro de control:
            // la cámara y la alarma no deben pararse por eso.
            switch phase {
            case .active: resume()
            case .background: pause()
            default: break
            }
        }
    }

    /// Arranque de la app.
    @MainActor
    private func setup() {
        // La pantalla nunca se apaga sola.
        UIApplication.shared.isIdleTimerDisabled = true
        TouchWatcher.install()
        OrientationLock.apply(settings.orientationMode)
        BrightnessController.shared.idleOverlay = settings.idleDim

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
        UIApplication.shared.isIdleTimerDisabled = true
        BrightnessController.shared.start()
        store.startPolling()
        link.start()
        weather.start()
        StreamServer.shared.start()
        camera.start()
    }

    @MainActor
    private func pause() {
        // Al salir de la app, el iPhone recupera su brillo normal.
        BrightnessController.shared.stop()
        store.stopPolling()
        link.stop()
        weather.stop()
        StreamServer.shared.stop()
        camera.stop()
    }
}
