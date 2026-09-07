import SwiftUI

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
    }
}

struct FaintDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}
