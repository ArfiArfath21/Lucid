//
//  SoundManager.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import AVFoundation
import AudioToolbox
import MediaPlayer

class SoundManager: ObservableObject {
    @Published var availableSounds: [Sound] = []
    private var audioPlayer: AVAudioPlayer?
    private var soundID: SystemSoundID = 0
    private var timer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        loadAvailableSounds()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    deinit {
        timer?.invalidate()
        endBackgroundTask()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        // Set up the remote command center to handle control center and lock screen controls
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Disable default controls that aren't relevant for an alarm
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        
        // But enable stop command so users can at least silence the alarm from control center
        // (they'll still need to come to the app to answer the question)
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] event in
            self?.stopAlarmSound()
            return .success
        }
    }
    
    private func loadAvailableSounds() {
        // Using system sound IDs that are suitable for alarms
        availableSounds = [
            Sound(id: "1000", name: "Trill"),
            Sound(id: "1001", name: "Chirp"),
            Sound(id: "1002", name: "Xylophone"),
            Sound(id: "1003", name: "Bell"),
            Sound(id: "1004", name: "Electronic"),
            Sound(id: "1005", name: "Alarm"),
            Sound(id: "1007", name: "Descending"),
            Sound(id: "1008", name: "Ascending"),
            Sound(id: "1009", name: "Chime"),
            Sound(id: "1010", name: "Glass"),
            Sound(id: "1013", name: "Tink"),
            Sound(id: "1014", name: "Horn"),
            Sound(id: "1020", name: "Anticipate"),
            Sound(id: "1023", name: "Bloom")
        ]
    }
    
    func getAvailableSounds() -> [Sound] {
        return availableSounds
    }
    
    func getDefaultSound() -> Sound {
        return availableSounds.first(where: { $0.id == "1005" }) ?? availableSounds.first!
    }
    
    func playAlarmSound(sound: Sound) {
        // Stop any existing sound first
        stopAlarmSound()
        
        // Begin background task to keep app running
        beginBackgroundTask()
        
        // Ensure audio session is properly configured for alarm playback
        setupAudioSession()
        
        // Update now playing info for lock screen
        updateNowPlayingInfo(soundName: sound.name)
        
        // Try to use bundled alarm sounds
        if let url = getBundledAlarmSound(named: sound.name) {
            playBundledSound(url: url)
            return
        }
        
        // Fall back to system sounds
        guard let soundIDInt = Int(sound.id), let systemSoundID = SystemSoundID(exactly: soundIDInt) else {
            // Fallback to default system sound if id conversion fails
            AudioServicesPlaySystemSound(1005) // Default alarm sound
            
            // Set up a timer to play repeatedly
            setupRepeatingSound(1005)
            return
        }
        
        // Play system sound
        AudioServicesPlaySystemSound(systemSoundID)
        
        // Set up a timer to play repeatedly
        setupRepeatingSound(systemSoundID)
    }
    
    private func getBundledAlarmSound(named soundName: String) -> URL? {
        // First try to find in bundle
        if let path = Bundle.main.path(forResource: soundName, ofType: "caf") {
            return URL(fileURLWithPath: path)
        }
        
        // Then try system sounds path
        let systemSoundPath = "/System/Library/Audio/UISounds/\(soundName).caf"
        if FileManager.default.fileExists(atPath: systemSoundPath) {
            return URL(fileURLWithPath: systemSoundPath)
        }
        
        return nil
    }
    
    private func playBundledSound(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing bundled sound: \(error.localizedDescription)")
            
            // Fall back to system sound
            AudioServicesPlaySystemSound(1005)
            setupRepeatingSound(1005)
        }
    }
    
    private func updateNowPlayingInfo(soundName: String) {
        // Set now playing info for lock screen display
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Lucid Alarm"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Tap to answer question"
        
        // Create a simple alarm clock image for the lock screen
        if let image = UIImage(systemName: "alarm.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRepeatingSound(_ soundID: SystemSoundID) {
        // Save the sound ID to instance variable
        self.soundID = soundID
        
        // Cancel any existing timer
        timer?.invalidate()
        
        // Create a repeating timer that plays the sound every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.soundID != 0 {
                AudioServicesPlaySystemSound(self.soundID)
                
                // Make sure our background task doesn't expire
                self.extendBackgroundTask()
            } else {
                timer.invalidate()
            }
        }
        
        // Make sure the timer runs in background modes
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stopAlarmSound() {
        // Stop any audio player
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Clear the sound ID to stop the repeating timer
        soundID = 0
        
        // Invalidate timer
        timer?.invalidate()
        timer = nil
        
        // End background task
        endBackgroundTask()
        
        // Reset now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error stopping alarm sound: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()
        
        // Start a new background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AlarmSoundTask") { [weak self] in
            // This is the expiration handler, clean up if the task expires
            self?.endBackgroundTask()
        }
    }
    
    private func extendBackgroundTask() {
        // End the current task and start a new one if we're approaching expiration
        if backgroundTaskID != .invalid {
            endBackgroundTask()
            beginBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}
