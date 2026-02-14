import Foundation

/// Extracts action items from LLM responses using structured markers
/// Format: [ACTION: description | ENERGY: level | TIMEFRAME: time]
public class ActionExtractor {

    // MARK: - Types

    public struct ExtractedAction: Equatable {
        public let description: String
        public let energy: EnergyLevel
        public let timeframe: Timeframe

        public init(description: String, energy: EnergyLevel, timeframe: Timeframe) {
            self.description = description
            self.energy = energy
            self.timeframe = timeframe
        }

        public enum EnergyLevel: String, Equatable {
            case high
            case medium
            case low
        }

        public enum Timeframe: String, Equatable {
            case today = "today"
            case thisWeek = "this-week"
            case someday = "someday"
        }
    }

    public struct ExtractedMealAction {
        public let day: String
        public let meal: String
        public let recipeTitle: String
        public let recipeId: Int64?
    }

    public struct ExtractedShopAction {
        public let ingredient: String
        public let amount: Double?
        public let unit: String?
        public let category: String?
    }

    // MARK: - Private Properties

    /// Regex pattern to match action markers
    /// Format: [ACTION: description | ENERGY: level | TIMEFRAME: time]
    private let actionPattern = #"\[ACTION:\s*([^|]+)\s*\|\s*ENERGY:\s*(\w+)\s*\|\s*TIMEFRAME:\s*([^\]]+)\]"#

    /// Regex pattern to match meal markers
    /// Format: [MEAL: day | meal | recipe title | recipe_id: id]
    private let mealPattern = #"\[MEAL:\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+?)\s*\|\s*recipe_id:\s*(\d+)\s*\]"#

    /// Regex pattern to match shop markers
    /// Format: [SHOP: ingredient | amount | unit | category]
    private let shopPattern = #"\[SHOP:\s*([^|]+?)\s*\|\s*([\d.]+)\s*\|\s*([^|]+?)\s*\|\s*(\w+)\s*\]"#

    // MARK: - Init

    public init() {}

    // MARK: - Public Methods

    /// Extract all action items from an LLM response
    /// - Parameter response: The LLM response string
    /// - Returns: Array of extracted actions
    public func extractActions(from response: String) -> [ExtractedAction] {
        guard let regex = try? NSRegularExpression(pattern: actionPattern, options: .caseInsensitive) else {
            return []
        }

        let range = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, options: [], range: range)

        return matches.compactMap { match -> ExtractedAction? in
            guard match.numberOfRanges >= 4,
                  let descriptionRange = Range(match.range(at: 1), in: response),
                  let energyRange = Range(match.range(at: 2), in: response),
                  let timeframeRange = Range(match.range(at: 3), in: response) else {
                return nil
            }

            let description = String(response[descriptionRange]).trimmingCharacters(in: .whitespaces)
            let energyString = String(response[energyRange]).trimmingCharacters(in: .whitespaces).lowercased()
            let timeframeString = String(response[timeframeRange]).trimmingCharacters(in: .whitespaces).lowercased()

            // Parse energy with default fallback
            let energy = ExtractedAction.EnergyLevel(rawValue: energyString) ?? .medium

            // Parse timeframe with default fallback
            let timeframe = ExtractedAction.Timeframe(rawValue: timeframeString) ?? .someday

            return ExtractedAction(
                description: description,
                energy: energy,
                timeframe: timeframe
            )
        }
    }

    /// Remove action markers from a response for display
    /// - Parameter response: The LLM response string with action markers
    /// - Returns: Cleaned string without action markers
    public func removeActionMarkers(from response: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: actionPattern, options: .caseInsensitive) else {
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let range = NSRange(response.startIndex..., in: response)
        var result = regex.stringByReplacingMatches(in: response, options: [], range: range, withTemplate: "")

        // Clean up multiple consecutive newlines and whitespace
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Meal Extraction

    /// Extract all meal actions from an LLM response
    /// - Parameter response: The LLM response string
    /// - Returns: Array of extracted meal actions
    public func extractMealActions(from response: String) -> [ExtractedMealAction] {
        guard let regex = try? NSRegularExpression(pattern: mealPattern, options: .caseInsensitive) else {
            return []
        }

        let range = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, options: [], range: range)

        return matches.compactMap { match -> ExtractedMealAction? in
            guard match.numberOfRanges >= 5,
                  let dayRange = Range(match.range(at: 1), in: response),
                  let mealRange = Range(match.range(at: 2), in: response),
                  let titleRange = Range(match.range(at: 3), in: response),
                  let idRange = Range(match.range(at: 4), in: response) else {
                return nil
            }

            let day = String(response[dayRange]).trimmingCharacters(in: .whitespaces).lowercased()
            let meal = String(response[mealRange]).trimmingCharacters(in: .whitespaces).lowercased()
            let recipeTitle = String(response[titleRange]).trimmingCharacters(in: .whitespaces)
            let idString = String(response[idRange]).trimmingCharacters(in: .whitespaces)

            // recipe_id: 0 means no matching recipe
            let recipeId: Int64?
            if let parsed = Int64(idString), parsed > 0 {
                recipeId = parsed
            } else {
                recipeId = nil
            }

            return ExtractedMealAction(
                day: day,
                meal: meal,
                recipeTitle: recipeTitle,
                recipeId: recipeId
            )
        }
    }

    // MARK: - Shop Extraction

    /// Extract all shop actions from an LLM response
    /// - Parameter response: The LLM response string
    /// - Returns: Array of extracted shop actions
    public func extractShopActions(from response: String) -> [ExtractedShopAction] {
        guard let regex = try? NSRegularExpression(pattern: shopPattern, options: .caseInsensitive) else {
            return []
        }

        let range = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, options: [], range: range)

        return matches.compactMap { match -> ExtractedShopAction? in
            guard match.numberOfRanges >= 5,
                  let ingredientRange = Range(match.range(at: 1), in: response),
                  let amountRange = Range(match.range(at: 2), in: response),
                  let unitRange = Range(match.range(at: 3), in: response),
                  let categoryRange = Range(match.range(at: 4), in: response) else {
                return nil
            }

            let ingredient = String(response[ingredientRange]).trimmingCharacters(in: .whitespaces)
            let amountString = String(response[amountRange]).trimmingCharacters(in: .whitespaces)
            let unit = String(response[unitRange]).trimmingCharacters(in: .whitespaces)
            let category = String(response[categoryRange]).trimmingCharacters(in: .whitespaces)

            let amount = Double(amountString)

            return ExtractedShopAction(
                ingredient: ingredient,
                amount: amount,
                unit: unit.isEmpty ? nil : unit,
                category: category.isEmpty ? nil : category
            )
        }
    }

    // MARK: - Meal & Shop Marker Removal

    /// Remove meal and shop markers from a response for display
    /// - Parameter response: The LLM response string with meal/shop markers
    /// - Returns: Cleaned string without meal/shop markers
    public func removeMealAndShopMarkers(from response: String) -> String {
        var result = response

        // Remove MEAL markers
        if let mealRegex = try? NSRegularExpression(pattern: mealPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = mealRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // Remove SHOP markers
        if let shopRegex = try? NSRegularExpression(pattern: shopPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = shopRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // Clean up multiple consecutive newlines and whitespace
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
