import SwiftUI
enum HeroDetailSection: String, CaseIterable { case augments = "推荐海克斯", standard = "常规玩法" }
struct HeroDetailSegments: View {
    @Binding var selection: HeroDetailSection
    var body: some View {
        HStack(spacing: 6) {
            ForEach(HeroDetailSection.allCases, id: \.self) { value in
                Button { selection = value } label: {
                    Text(value.rawValue).font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == value ? Theme.text : Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(selection == value ? Theme.secondary.opacity(0.25) : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }.padding(6).background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
