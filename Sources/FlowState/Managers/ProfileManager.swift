import Foundation
import AppKit

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var appProfiles: [AppProfile] = []
    @Published var groqAPIKey: String = ""
    
    private let profilesKey = "userAppProfiles"
    private let groqKeyKey = "groqAPIKey"
    
    private init() {
        loadProfiles()
        loadAPIKey()
    }
    
    // MARK: - Persistence
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([AppProfile].self, from: data) {
            appProfiles = decoded
        } else {
            // First launch: use defaults
            appProfiles = AppProfile.defaultMappings
            saveProfiles()
        }
    }
    
    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(appProfiles) {
            UserDefaults.standard.set(encoded, forKey: profilesKey)
        }
    }
    
    private func loadAPIKey() {
        groqAPIKey = UserDefaults.standard.string(forKey: groqKeyKey) ?? ""
    }
    
    func saveAPIKey(_ key: String) {
        groqAPIKey = key
        UserDefaults.standard.set(key, forKey: groqKeyKey)
    }
    
    // MARK: - Category Lookup
    
    func category(for bundleId: String?) -> ProfileCategory {
        guard let bundleId = bundleId else { return .default }
        return appProfiles.first { $0.id == bundleId }?.category ?? .default
    }
    
    func categoryForFrontmostApp() -> ProfileCategory {
        let frontApp = NSWorkspace.shared.frontmostApplication
        return category(for: frontApp?.bundleIdentifier)
    }
    
    // MARK: - Profile Management
    
    func updateCategory(for bundleId: String, to category: ProfileCategory) {
        if let index = appProfiles.firstIndex(where: { $0.id == bundleId }) {
            appProfiles[index].category = category
        } else {
            // Add new app
            let appName = NSWorkspace.shared.runningApplications
                .first { $0.bundleIdentifier == bundleId }?.localizedName ?? bundleId
            appProfiles.append(AppProfile(id: bundleId, name: appName, category: category))
        }
        saveProfiles()
    }
    
    func resetToDefaults() {
        appProfiles = AppProfile.defaultMappings
        saveProfiles()
    }
    
    // MARK: - Installed Apps Discovery
    
    func discoverInstalledApps() -> [AppProfile] {
        var apps: [AppProfile] = []
        let appURLs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        
        for appDir in appURLs {
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: appDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) {
                for url in contents where url.pathExtension == "app" {
                    if let bundle = Bundle(url: url),
                       let bundleId = bundle.bundleIdentifier,
                       let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                        // Check if already in our list
                        let existing = appProfiles.first { $0.id == bundleId }
                        let category = existing?.category ?? .default
                        apps.append(AppProfile(id: bundleId, name: name, category: category))
                    }
                }
            }
        }
        
        return apps.sorted { $0.name < $1.name }
    }
}
