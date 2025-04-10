//
//  QuestionView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI

struct QuestionView: View {
    @ObservedObject var viewModel: AlarmViewModel
    @State private var userAnswer = ""
    @State private var selectedMCQAnswer: String?
    @State private var isButtonDisabled = false
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Current time
                Text(currentTimeString)
                    .font(.system(size: 60, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
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
                    }
                
                Spacer()
                
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
        }
    }
    
    // MARK: - Computed Properties
    @State private var pulseAnimation = false
    
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
    
    private func autocapitalizationForQuestionType(_ type: QuestionType) -> UITextAutocapitalizationType {
        switch type {
        case .wordScramble:
            return .allCharacters
        default:
            return .none
        }
    }
}

struct QuestionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AlarmViewModel()
        QuestionView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}
