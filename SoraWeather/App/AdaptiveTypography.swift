import SwiftUI

private struct AdaptiveType: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat
    let weight: Font.Weight
    init(size: CGFloat, weight: Font.Weight) { _size = ScaledMetric(wrappedValue: size, relativeTo: .body); self.weight = weight }
    func body(content: Content) -> some View { content.font(.system(size: size, weight: weight)) }
}
extension View {
    func soraFont(size: CGFloat, weight: Font.Weight = .regular) -> some View { modifier(AdaptiveType(size: size, weight: weight)) }
}
