import Foundation
import SeleneShared

extension Message {
    /// Computed property for attributed content with citations.
    /// Lives in SeleneChat because it depends on CitationParser.
    var attributedContent: AttributedString? {
        guard !isUser, let cited = citedNotes, !cited.isEmpty else {
            return nil
        }

        let parseResult = CitationParser.parse(content)
        return parseResult.attributedText
    }
}
