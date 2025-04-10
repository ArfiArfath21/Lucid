//
//  QuestionModels.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case simpleMath = "Simple Math with a Twist"
    case wordScramble = "Word Scrambles"
    case readingComprehension = "Reading Comprehension"
    case verbalMath = "Verbal Math"
    
    var id: String { self.rawValue }
}

enum QuestionFormat: String, Codable, CaseIterable {
    case openEnded = "Open Ended"
    case multipleChoice = "Multiple Choice"
}

struct MCQOption: Identifiable, Codable, Equatable {
    var id = UUID()
    let text: String
    let isCorrect: Bool
}

struct Question: Identifiable {
    var id = UUID()
    let questionText: String
    let correctAnswer: String
    let questionType: QuestionType
    var format: QuestionFormat = .openEnded
    var mcqOptions: [MCQOption]?
    
    // Helper for comparing user answers with correct answers
    func isCorrect(userAnswer: String) -> Bool {
        if format == .openEnded {
            // Normalize both answers by trimming whitespace and converting to lowercase
            let normalizedUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedCorrectAnswer = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            return normalizedUserAnswer == normalizedCorrectAnswer
        } else if format == .multipleChoice, let options = mcqOptions {
            // For MCQ, check if the selected option text matches the correct option
            return options.first(where: { $0.text == userAnswer })?.isCorrect ?? false
        }
        
        return false
    }
}
