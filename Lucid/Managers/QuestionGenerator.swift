//
//  QuestionGenerator.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation

class QuestionGenerator {
    // Simple Math with a Twist questions
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
    
    // Get a random question from all question types
    func generateRandomQuestion(from types: [QuestionType]) -> Question {
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
        
        switch randomType {
        case .simpleMath:
            return generateMathQuestion()
        case .wordScramble:
            return generateWordScrambleQuestion()
        case .readingComprehension:
            return generateReadingComprehensionQuestion()
        case .verbalMath:
            return generateVerbalMathQuestion()
        }
    }
    
    func generateMathQuestion() -> Question {
        return mathQuestions.randomElement()!
    }
    
    func generateWordScrambleQuestion() -> Question {
        return wordScrambleQuestions.randomElement()!
    }
    
    func generateReadingComprehensionQuestion() -> Question {
        return readingComprehensionQuestions.randomElement()!
    }
    
    func generateVerbalMathQuestion() -> Question {
        return verbalMathQuestions.randomElement()!
    }
    
    func checkAnswer(question: Question, userAnswer: String) -> Bool {
        return question.isCorrect(userAnswer: userAnswer)
    }
    
    // Generate a sample question for preview or testing
    func generateSampleQuestion() -> Question {
        let sampleQuestions = [
            mathQuestions[0],
            wordScrambleQuestions[0],
            readingComprehensionQuestions[0],
            verbalMathQuestions[0]
        ]
        
        return sampleQuestions.randomElement()!
    }
}
