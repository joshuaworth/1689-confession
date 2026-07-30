import UIKit

/// One vocabulary of touch, used consistently: opening a proof is a light tick,
/// a bookmark is firm, crossing into a new chapter while scrolling is the softest.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)

    static func proof() { light.impactOccurred(intensity: 0.7) }
    static func bookmark() { rigid.impactOccurred() }
    static func chapterBoundary() { soft.impactOccurred(intensity: 0.45) }
    static func arrive() { light.impactOccurred(intensity: 0.5) }
}
