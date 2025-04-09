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

struct Question: Identifiable {
    var id = UUID()
    let questionText: String
    let correctAnswer: String
    let questionType: QuestionType
    
    // Helper for comparing user answers with correct answers
    func isCorrect(userAnswer: String) -> Bool {
        // Normalize both answers by trimming whitespace and converting to lowercase
        let normalizedUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCorrectAnswer = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        return normalizedUserAnswer == normalizedCorrectAnswer
    }
}
