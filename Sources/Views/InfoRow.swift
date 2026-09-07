import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(bold ? .primary : .secondary)
                .font(.system(size: bold ? 15 : 13, weight: bold ? .bold : .regular))
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .font(.system(size: bold ? 15 : 13, weight: bold ? .bold : .regular))
        }
        .padding(.vertical, 3)
    }
}
