//
//  MCQQuestionView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import SwiftUI

struct MCQQuestionView: View {
    let question: Question
    @Binding var selectedOption: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Question text
            Text(question.questionText)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            // Options
            if let options = question.mcqOptions {
                VStack(spacing: 12) {
                    ForEach(options) { option in
                        Button(action: {
                            selectedOption = option.text
                        }) {
                            HStack {
                                Text(option.text)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                // Show checkmark if this option is selected
                                if selectedOption == option.text {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                        .font(.title3)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(selectedOption == option.text ? 0.3 : 0.15))
                            )
                            .animation(.easeInOut(duration: 0.2), value: selectedOption)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MCQQuestionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            MCQQuestionView(
                question: Question(
                    questionText: "What is the capital of France?",
                    correctAnswer: "Paris",
                    questionType: .readingComprehension,
                    format: .multipleChoice,
                    mcqOptions: [
                        MCQOption(text: "Paris", isCorrect: true),
                        MCQOption(text: "London", isCorrect: false),
                        MCQOption(text: "Berlin", isCorrect: false),
                        MCQOption(text: "Rome", isCorrect: false)
                    ]
                ),
                selectedOption: .constant("Paris")
            )
        }
    }
}
