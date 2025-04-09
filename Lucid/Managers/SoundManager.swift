//
//  SoundManager.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import AVFoundation
import AudioToolbox

class SoundManager: ObservableObject {
    @Published var availableSounds: [Sound] = []
    private var audioPlayer: AVAudioPlayer?
    private var soundID: SystemSoundID = 0
    
    init() {
        loadAvailableSounds()
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
        
        guard let soundIDInt = Int(sound.id), let systemSoundID = SystemSoundID(exactly: soundIDInt) else {
            // Fallback to default system sound if id conversion fails
            AudioServicesPlaySystemSound(1005) // Default alarm sound
            return
        }
        
        // For repeating alarms, we need a more complex approach
        // because system sounds only play once
        
        // Try to create a URL for the system sound
        let systemSoundURL = URL(string: "/System/Library/Audio/UISounds/\(sound.name).caf")
        
        if let url = systemSoundURL, FileManager.default.fileExists(atPath: url.path) {
            // If we can access the system sound file, play it on repeat
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1 // Loop indefinitely
                audioPlayer?.play()
            } catch {
                print("Error playing system sound: \(error.localizedDescription)")
                
                // Fallback to single play
                AudioServicesPlaySystemSound(systemSoundID)
                
                // Set up a timer to play repeatedly
                setupRepeatingSound(systemSoundID)
            }
        } else {
            // If we can't get the URL, just play the system sound ID
            AudioServicesPlaySystemSound(systemSoundID)
            
            // Set up a timer to play repeatedly
            setupRepeatingSound(systemSoundID)
        }
    }
    
    private func setupRepeatingSound(_ soundID: SystemSoundID) {
        // Save the sound ID to instance variable
        self.soundID = soundID
        
        // Create a repeating timer that plays the sound every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.soundID != 0 {
                AudioServicesPlaySystemSound(self.soundID)
            } else {
                timer.invalidate()
            }
        }
    }
    
    func stopAlarmSound() {
        // Stop any audio player
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Clear the sound ID to stop the repeating timer
        soundID = 0
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error stopping alarm sound: \(error.localizedDescription)")
        }
    }
}
