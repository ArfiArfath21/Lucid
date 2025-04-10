//
//  QuestionGenerator.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI

class QuestionGenerator {
    // Simple Math with a Twist questions (fallback questions)
    private let mathQuestions: [Question] = [
        Question(questionText: "What is (37 × 4) - 23 + 18?", correctAnswer: "143", questionType: .simpleMath),
        Question(questionText: "Calculate: 125 ÷ 5 × 3 - 17", correctAnswer: "58", questionType: .simpleMath),
        Question(questionText: "What is the result of 16² - 24 × 3?", correctAnswer: "184", questionType: .simpleMath),
        Question(questionText: "Solve: 72 ÷ 8 + 17 × 2", correctAnswer: "43", questionType: .simpleMath),
        Question(questionText: "Calculate: (45 - 18) × (6 + 2) ÷ 3", correctAnswer: "72", questionType: .simpleMath)
    ]
    
    // Word Scrambles questions
    private let wordScrambleQuestions: [Question] = [
        Question(questionText: "Unscramble: PPLAE", correctAnswer: "APPLE", questionType: .wordScramble),
        Question(questionText: "Unscramble: OMPTEURC", correctAnswer: "COMPUTER", questionType: .wordScramble),
        Question(questionText: "Unscramble: KSABRFATE", correctAnswer: "BREAKFAST", questionType: .wordScramble),
        Question(questionText: "Unscramble: UOATNMIN", correctAnswer: "MOUNTAIN", questionType: .wordScramble),
        Question(questionText: "Unscramble: ENOHPTLEE", correctAnswer: "TELEPHONE", questionType: .wordScramble)
    ]
    
    // Reading Comprehension questions
    private let readingComprehensionQuestions: [Question] = [
        Question(questionText: "Marie walked to the store on Monday. She bought milk, eggs, and bread. The milk cost $2.50, the eggs cost $3.25, and the bread cost $1.75. How much did Marie spend in total?", correctAnswer: "$7.50", questionType: .readingComprehension),
        Question(questionText: "John has 3 blue shirts, 4 white shirts, and 2 black shirts in his closet. If he randomly selects a shirt, what is the probability he selects a white shirt? Express your answer as a fraction.", correctAnswer: "4/9", questionType: .readingComprehension),
        Question(questionText: "The library is open from 9 AM to 8 PM on weekdays, 10 AM to 6 PM on Saturdays, and 12 PM to 5 PM on Sundays. How many hours is the library open in a week?", correctAnswer: "67", questionType: .readingComprehension),
        Question(questionText: "Sarah planted 12 rose bushes in 3 equal rows. How many rose bushes are in each row?", correctAnswer: "4", questionType: .readingComprehension),
        Question(questionText: "A recipe requires 2.5 cups of flour to make 2 dozen cookies. How many cups of flour are needed to make 3 dozen cookies?", correctAnswer: "3.75", questionType: .readingComprehension)
    ]
    
    // Verbal Math questions
    private let verbalMathQuestions: [Question] = [
        Question(questionText: "If you have eight apples and give three to your friend, how many apples do you have left?", correctAnswer: "5", questionType: .verbalMath),
        Question(questionText: "A train travels at 60 miles per hour. How far will it travel in 2.5 hours?", correctAnswer: "150", questionType: .verbalMath),
        Question(questionText: "If a shirt costs $24 and is on sale for 25% off, what is the sale price?", correctAnswer: "$18", questionType: .verbalMath),
        Question(questionText: "Two friends split a bill of $45. If one paid $5 more than the other, how much did each person pay?", correctAnswer: "$20,$25", questionType: .verbalMath),
        Question(questionText: "If you read 15 pages every day, how many pages will you read in two weeks?", correctAnswer: "210", questionType: .verbalMath)
    ]
    
    // OpenAI service for generating questions
    private var openAIService: OpenAIService?
    
    // User preferences
    private var preferMultipleChoice: Bool {
        return UserDefaults.standard.bool(forKey: "preferMultipleChoice")
    }
    
    private var useAIValidation: Bool {
        return UserDefaults.standard.bool(forKey: "useAIValidation")
    }
    
    // MARK: - Initialization and Configuration
    init() {
        configureOpenAI()
        
        // Listen for API key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(apiKeyChanged),
            name: Notification.Name("APIKeyChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func apiKeyChanged() {
        configureOpenAI()
    }
    
    func configureOpenAI() {
        if let apiKey = KeyManager.getAPIKey() {
            self.openAIService = OpenAIService(apiKey: apiKey)
        } else {
            self.openAIService = nil
        }
    }
    
    // MARK: - Question Generation Methods
    func generateRandomQuestion(from types: [QuestionType]) async -> Question {
        // If no types are specified, return a default question
        guard !types.isEmpty else {
            return Question(
                questionText: "What is 5 + 5?",
                correctAnswer: "10",
                questionType: .simpleMath
            )
        }
        
        // Select a random question type from the provided types
        let randomType = types.randomElement()!
        
        // Get appropriate question format based on user preference
        let format: QuestionFormat = preferMultipleChoice ? .multipleChoice : .openEnded
        
        // Try to generate a question using OpenAI if available and enabled
        if useAIValidation, let openAIService = openAIService {
            do {
                var question = try await openAIService.generateQuestion(type: randomType, format: format)
                // Set the question type (the API response doesn't include this)
                question = Question(
                    questionText: question.questionText,
                    correctAnswer: question.correctAnswer,
                    questionType: randomType,
                    format: question.format,
                    mcqOptions: question.mcqOptions
                )
                return question
            } catch {
                print("Error generating question with OpenAI: \(error)")
                // Fall back to hardcoded questions
            }
        }
        
        // Fallback to hardcoded questions
        return fallbackQuestion(for: randomType)
    }
    
    // MARK: - Answer Validation
    func checkAnswer(question: Question, userAnswer: String) async -> Bool {
        // For MCQ questions, the validation is straightforward
        if question.format == .multipleChoice {
            return question.isCorrect(userAnswer: userAnswer)
        }
        
        // For open-ended questions, try to use AI validation if enabled
        if useAIValidation, let openAIService = openAIService {
            do {
                return try await openAIService.validateAnswer(question: question, userAnswer: userAnswer)
            } catch {
                print("Error validating answer with OpenAI: \(error)")
                // Fall back to basic validation
            }
        }
        
        // Fallback to basic string comparison
        return question.isCorrect(userAnswer: userAnswer)
    }
    
    // MARK: - Helper Methods
    private func fallbackQuestion(for type: QuestionType) -> Question {
        // Select a hardcoded question of the appropriate type
        let question: Question
        
        switch type {
        case .simpleMath:
            question = mathQuestions.randomElement()!
        case .wordScramble:
            question = wordScrambleQuestions.randomElement()!
        case .readingComprehension:
            question = readingComprehensionQuestions.randomElement()!
        case .verbalMath:
            question = verbalMathQuestions.randomElement()!
        }
        
        // If multiple choice is preferred, convert to an MCQ
        if preferMultipleChoice {
            return convertToMCQ(question)
        }
        
        return question
    }
    
    private func convertToMCQ(_ question: Question) -> Question {
        // Create a multiple-choice version of a standard question
        // This is a simplified implementation - in a real app, you'd want to generate
        // more plausible but incorrect answers based on the question type
        
        let correctAnswer = question.correctAnswer
        
        // Generate some basic incorrect options based on question type
        var incorrectOptions: [String] = []
        
        switch question.questionType {
        case .simpleMath, .verbalMath:
            // For math questions, use close numbers
            if let correctNum = Int(correctAnswer.filter { $0.isNumber }) {
                incorrectOptions.append("\(correctNum + 1)")
                incorrectOptions.append("\(correctNum - 1)")
                incorrectOptions.append("\(correctNum * 2)")
            } else {
                incorrectOptions = ["25", "42", "100"]
            }
            
        case .wordScramble:
            // For word scrambles, use other words
            incorrectOptions = ["BANANA", "ORANGE", "LAPTOP"]
            
        case .readingComprehension:
            // For reading comprehension, use plausible but wrong answers
            incorrectOptions = ["$6.75", "70", "3"]
        }
        
        // Ensure we have 3 incorrect options
        while incorrectOptions.count < 3 {
            incorrectOptions.append("Option \(incorrectOptions.count + 1)")
        }
        
        // Trim to 3 options if we have more
        incorrectOptions = Array(incorrectOptions.prefix(3))
        
        // Create MCQ options including the correct one
        let options = [
            MCQOption(text: correctAnswer, isCorrect: true),
            MCQOption(text: incorrectOptions[0], isCorrect: false),
            MCQOption(text: incorrectOptions[1], isCorrect: false),
            MCQOption(text: incorrectOptions[2], isCorrect: false),
        ].shuffled() // Randomize order
        
        return Question(
            questionText: question.questionText,
            correctAnswer: correctAnswer,
            questionType: question.questionType,
            format: .multipleChoice,
            mcqOptions: options
        )
    }
    
    // Generate a sample question for preview or testing
    func generateSampleQuestion() -> Question {
        let sampleQuestions = [
            mathQuestions[0],
            wordScrambleQuestions[0],
            readingComprehensionQuestions[0],
            verbalMathQuestions[0]
        ]
        
        let question = sampleQuestions.randomElement()!
        
        // If multiple choice is preferred, convert to MCQ
        if preferMultipleChoice {
            return convertToMCQ(question)
        }
        
        return question
    }
}
