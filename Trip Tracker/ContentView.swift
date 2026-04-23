import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tint)
            Text("Trip Tracker")
                .font(.title2.weight(.semibold))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
