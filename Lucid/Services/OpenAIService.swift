//
//  OpenAIService.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation

class OpenAIService {
    private let apiKey: String
    private let provider: APIProvider
    private let baseUrl: String
    private let model = "gpt-4o"
    
    // Azure specific properties
    private let azureResourceName: String?
    private let azureDeploymentId: String?
    private let azureApiVersion: String
    
    init(
        apiKey: String,
        provider: APIProvider = KeyManager.getAPIProvider(),
        baseUrl: String = KeyManager.getBaseURL(),
        azureResourceName: String? = KeyManager.getAzureResourceName(),
        azureDeploymentId: String? = KeyManager.getAzureDeploymentId(),
        azureApiVersion: String = KeyManager.getAzureApiVersion()
    ) {
        self.apiKey = apiKey
        self.provider = provider
        self.baseUrl = baseUrl
        self.azureResourceName = azureResourceName
        self.azureDeploymentId = azureDeploymentId
        self.azureApiVersion = azureApiVersion
    }
    
    enum OpenAIError: Error, LocalizedError {
        case invalidURL
        case missingAzureConfiguration
        case requestFailed(Error)
        case networkError(Error)
        case serverError(Int, String)
        case rateLimitExceeded
        case invalidAPIKey
        case invalidResponse
        case decodingFailed(Error)
        case serviceUnavailable
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL format."
            case .missingAzureConfiguration:
                return "Missing required Azure configuration (resource name or deployment ID)."
            case .requestFailed(let error):
                return "Request failed: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .serverError(let code, let message):
                return "Server error (\(code)): \(message)"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later."
            case .invalidAPIKey:
                return "Invalid API key. Please check your API key in settings."
            case .invalidResponse:
                return "Received an invalid response from the server."
            case .decodingFailed(let error):
                return "Failed to decode the response: \(error.localizedDescription)"
            case .serviceUnavailable:
                return "AI service is currently unavailable. Please try again later."
            case .timeout:
                return "Request timed out. Please check your internet connection."
            }
        }
    }
    
    // MARK: - Generate Question
    func generateQuestion(type: QuestionType, format: QuestionFormat) async throws -> Question {
        let prompt = self.buildPromptForQuestion(type: type, format: format)
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that generates educational questions for an alarm app that requires users to answer questions to stop the alarm."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        let responseData = try await performRequest(endpoint: "chat/completions", body: requestBody)
        
        // Parse the response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        // Create question from the JSON response
        return try createQuestionFromJSON(contentData)
    }
    
    // MARK: - Validate Answer
    func validateAnswer(question: Question, userAnswer: String) async throws -> Bool {
        let prompt = """
        I have a question: "\(question.questionText)"
        The correct answer is: "\(question.correctAnswer)"
        The user answered: "\(userAnswer)"
        
        Is the user's answer correct? Consider different formats, equivalents, minor typos, and reasonable variations of the answer.
        Think carefully and return only a JSON response in the format {"isCorrect": true} or {"isCorrect": false}
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that evaluates answers to educational questions."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        let responseData = try await performRequest(endpoint: "chat/completions", body: requestBody)
        
        // Parse the response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        // Parse the validation result
        guard let validationJSON = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
              let isCorrect = validationJSON["isCorrect"] as? Bool else {
            throw OpenAIError.invalidResponse
        }
        
        return isCorrect
    }
    
    // MARK: - Helper Methods
    private func buildPromptForQuestion(type: QuestionType, format: QuestionFormat) -> String {
        var prompt = "Generate a \(type.rawValue) question"
        
        // Add format-specific instructions
        if format == .multipleChoice {
            prompt += " with exactly 4 multiple-choice options (one correct, three incorrect)."
        } else {
            prompt += " that can be answered with a short text answer."
        }
        
        // Add type-specific examples and difficulty guidance
        switch type {
        case .simpleMath:
            prompt += " Similar to: 'What is (37 × 4) - 23 + 18?' or 'Calculate: 125 ÷ 5 × 3 - 17'. The difficulty should be moderate - requiring a few steps of calculation but not too complex."
        case .wordScramble:
            prompt += " Similar to: 'Unscramble: PPLAE' (which would be 'APPLE'). Use common words that are scrambled."
        case .readingComprehension:
            prompt += " Similar to: 'Marie walked to the store on Monday. She bought milk for $2.50, eggs for $3.25, and bread for $1.75. How much did Marie spend in total?'. Keep it short but require careful reading."
        case .verbalMath:
            prompt += " Similar to: 'If you have eight apples and give three to your friend, how many apples do you have left?'. Use everyday scenarios with simple arithmetic."
        }
        
        // Add response format instructions
        prompt += """
        \n\nRespond with a JSON object in this exact format:
        {
          "questionText": "The question text here",
          "correctAnswer": "The correct answer here (as a string)"
        """
        
        // Add MCQ options if needed
        if format == .multipleChoice {
            prompt += """
        ,"mcqOptions": [
            {"text": "First option (the correct one)", "isCorrect": true},
            {"text": "Second option", "isCorrect": false},
            {"text": "Third option", "isCorrect": false},
            {"text": "Fourth option", "isCorrect": false}
          ]
        """
        }
        
        prompt += "}"
        
        prompt += "\n\nMake sure the difficulty level is appropriate for someone who has just woken up and needs to become alert."
        
        return prompt
    }
    
    private func createQuestionFromJSON(_ data: Data) throws -> Question {
        do {
            let decoder = JSONDecoder()
            
            // First try to decode with MCQ options
            if let questionData = try? decoder.decode(MCQQuestionData.self, from: data) {
                return Question(
                    questionText: questionData.questionText,
                    correctAnswer: questionData.correctAnswer,
                    questionType: .simpleMath, // We'll set the correct type later
                    format: .multipleChoice,
                    mcqOptions: questionData.mcqOptions
                )
            }
            
            // If that fails, try to decode as an open-ended question
            let questionData = try decoder.decode(OpenEndedQuestionData.self, from: data)
            return Question(
                questionText: questionData.questionText,
                correctAnswer: questionData.correctAnswer,
                questionType: .simpleMath, // We'll set the correct type later
                format: .openEnded,
                mcqOptions: nil
            )
            
        } catch {
            throw OpenAIError.decodingFailed(error)
        }
    }
    
    private func getFullURL(endpoint: String) throws -> URL {
        switch provider {
        case .openAI:
            guard let url = URL(string: "\(baseUrl)/\(endpoint)") else {
                throw OpenAIError.invalidURL
            }
            return url
            
        case .azureOpenAI:
            guard let resourceName = azureResourceName, !resourceName.isEmpty,
                  let deploymentId = azureDeploymentId, !deploymentId.isEmpty else {
                throw OpenAIError.missingAzureConfiguration
            }
            
            let apiVersion = azureApiVersion.isEmpty ? KeyManager.defaultAzureApiVersion : azureApiVersion
            
            // Format for Azure OpenAI:
            // https://{resource-name}.openai.azure.com/openai/deployments/{deployment-id}/chat/completions?api-version={api-version}
            let urlString = "https://\(resourceName).openai.azure.com/openai/deployments/\(deploymentId)/\(endpoint)?api-version=\(apiVersion)"
            
            guard let url = URL(string: urlString) else {
                throw OpenAIError.invalidURL
            }
            return url
        }
    }
    
    private func performRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        let url = try getFullURL(endpoint: endpoint)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set different authentication headers based on provider
        switch provider {
        case .openAI:
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .azureOpenAI:
            request.addValue(apiKey, forHTTPHeaderField: "api-key")
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add timeout
        request.timeoutInterval = 30.0
        
        // Add body to request
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw OpenAIError.invalidAPIKey
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                var errorMessage = "Server error"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }
                throw OpenAIError.serverError(httpResponse.statusCode, errorMessage)
            case 503:
                throw OpenAIError.serviceUnavailable
            default:
                throw OpenAIError.serverError(httpResponse.statusCode, "Unexpected error")
            }
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw OpenAIError.networkError(urlError)
            case .timedOut:
                throw OpenAIError.timeout
            default:
                throw OpenAIError.requestFailed(urlError)
            }
        } catch let openAIError as OpenAIError {
            throw openAIError
        } catch {
            throw OpenAIError.requestFailed(error)
        }
    }
    
    // MARK: - Testing Connection
    func testConnection() async -> Result<Void, OpenAIError> {
        do {
            // Simple request just to test the connection
            let requestBody: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "user", "content": "Hello, this is a connection test."]
                ],
                "max_tokens": 5
            ]
            
            _ = try await performRequest(endpoint: "chat/completions", body: requestBody)
            return .success(())
        } catch let error as OpenAIError {
            return .failure(error)
        } catch {
            return .failure(.requestFailed(error))
        }
    }
}

// Decodable structures for parsing OpenAI responses
private struct OpenEndedQuestionData: Decodable {
    let questionText: String
    let correctAnswer: String
}

private struct MCQQuestionData: Decodable {
    let questionText: String
    let correctAnswer: String
    let mcqOptions: [MCQOption]
}
