import SwiftUI

struct StatusBadge: View {
    let text: String
    let tone: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tone.opacity(0.15))
            .foregroundStyle(tone)
            .clipShape(Capsule())
    }
}
