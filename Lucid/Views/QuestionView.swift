//
//  QuestionView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI
import AVFoundation

struct QuestionView: View {
    @ObservedObject var viewModel: AlarmViewModel
    @State private var userAnswer = ""
    @State private var selectedMCQAnswer: String?
    @State private var isButtonDisabled = false
    @State private var isLoading = false
    @State private var keepDeviceAwake = true
    @State private var keepAwakeTimer: Timer? = nil
    @State private var pulseAnimation = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Current time with added padding to avoid the notch
                Text(currentTimeString)
                    .font(.system(size: 60, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                // Pulsating circle animation
                Circle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                            .opacity(pulseAnimation ? 0 : 1)
                            .animation(
                                Animation.easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                value: pulseAnimation
                            )
                    )
                    .onAppear {
                        pulseAnimation = true
                        startKeepAwakeTimer()
                    }
                    .onDisappear {
                        stopKeepAwakeTimer()
                    }
                
                // Reduced spacing instead of a full Spacer
                Spacer().frame(height: 20)
                
                // Question display
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else if let question = viewModel.currentQuestion {
                    if question.format == .multipleChoice {
                        // Multiple choice view
                        MCQQuestionView(question: question, selectedOption: $selectedMCQAnswer)
                    } else {
                        // Open-ended question view
                        VStack(spacing: 24) {
                            Text(question.questionText)
                                .font(.title2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            // Answer input field
                            TextField("Answer", text: $userAnswer)
                                .font(.title3)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .keyboardType(keyboardTypeForQuestionType(question.questionType))
                                .autocapitalization(autocapitalizationForQuestionType(question.questionType))
                                .disableAutocorrection(true)
                                .focused($isInputFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    submitAnswer()
                                }
                                // Add toolbar with Done button for numeric keyboards
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        if isNumericKeyboard(question.questionType) {
                                            Spacer()
                                            Button("Done") {
                                                isInputFocused = false
                                                submitAnswer()
                                            }
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal, 30)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 15) {
                    // Submit button
                    Button(action: submitAnswer) {
                        Text("Submit Answer")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    .disabled(isSubmitButtonDisabled || isButtonDisabled)
                    .opacity(isSubmitButtonDisabled || isButtonDisabled ? 0.6 : 1.0)
                    
                    // Override button (if enabled)
                    if viewModel.activeAlarm?.hasOverride == true {
                        Button(action: {
                            viewModel.useEmergencyOverride()
                        }) {
                            Text("Emergency Override")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            
            // Show result overlay
            if viewModel.showAnswerResult {
                VStack {
                    if viewModel.isAnswerCorrect {
                        Text("Correct!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        Text("Incorrect!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            if let question = viewModel.currentQuestion, question.format == .openEnded {
                isInputFocused = true
            }
            
            // Ensure device doesn't go to sleep
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            
            // Ensure audio session is active
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        .onDisappear {
            // Allow device to sleep again
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            
            // Stop playing periodic sound to keep app alive
            stopKeepAwakeTimer()
        }
    }
    
    // MARK: - Keep Device Awake Methods
    
    private func startKeepAwakeTimer() {
        // Create a timer that plays a silent sound every few seconds to keep the app active
        stopKeepAwakeTimer()
        
        keepAwakeTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            if keepDeviceAwake {
                // Try to re-activate audio session
                try? AVAudioSession.sharedInstance().setActive(true)
                
                // Play a silent sound if no sound is playing
                if !isAudioPlaying() {
                    playKeepAwakeSound()
                }
                
                // Make sure device doesn't sleep
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
        }
        
        if let timer = keepAwakeTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopKeepAwakeTimer() {
        keepAwakeTimer?.invalidate()
        keepAwakeTimer = nil
    }
    
    private func isAudioPlaying() -> Bool {
        // Check if audio is currently playing
        return AVAudioSession.sharedInstance().isOtherAudioPlaying
    }
    
    private func playKeepAwakeSound() {
        // Play a silent/subtle sound to keep the app alive
        AudioServicesPlaySystemSound(1104) // Very quiet system sound
    }
    
    // MARK: - Computed Properties
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: Date())
    }
    
    private var isSubmitButtonDisabled: Bool {
        if let question = viewModel.currentQuestion {
            if question.format == .openEnded {
                return userAnswer.isEmpty
            } else {
                return selectedMCQAnswer == nil
            }
        }
        return true
    }
    
    // MARK: - Methods
    private func submitAnswer() {
        if let question = viewModel.currentQuestion {
            // If input is empty, don't submit
            if question.format == .openEnded && userAnswer.isEmpty {
                return
            }
            
            // Disable button temporarily to prevent multiple submissions
            isButtonDisabled = true
            isLoading = true
            
            // Set the appropriate answer based on question type
            if question.format == .openEnded {
                viewModel.userAnswer = userAnswer
            } else {
                viewModel.userAnswer = selectedMCQAnswer ?? ""
            }
            
            // Check answer (async)
            Task {
                await viewModel.checkAnswer()
                
                // Reset UI state
                DispatchQueue.main.async {
                    isLoading = false
                    userAnswer = ""
                    selectedMCQAnswer = nil
                    
                    // Re-enable button after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isButtonDisabled = false
                        if let question = viewModel.currentQuestion, question.format == .openEnded {
                            isInputFocused = true
                        }
                    }
                }
            }
        }
    }
    
    private func keyboardTypeForQuestionType(_ type: QuestionType) -> UIKeyboardType {
        switch type {
        case .simpleMath, .verbalMath:
            return .decimalPad
        case .wordScramble:
            return .asciiCapable
        case .readingComprehension:
            return .default
        }
    }
    
    private func isNumericKeyboard(_ type: QuestionType) -> Bool {
        let keyboard = keyboardTypeForQuestionType(type)
        return keyboard == .decimalPad || keyboard == .numberPad
    }
    
    private func autocapitalizationForQuestionType(_ type: QuestionType) -> UITextAutocapitalizationType {
        switch type {
        case .wordScramble:
            return .allCharacters
        default:
            return .none
        }
    }
}

// Updated Preview that doesn't have initializer issues
struct QuestionView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionView(viewModel: AlarmViewModel())
            .preferredColorScheme(.dark)
    }
}
