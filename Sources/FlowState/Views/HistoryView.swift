import SwiftUI

struct HistoryView: View {
    @ObservedObject var manager = HistoryManager.shared
    var body: some View {
        List(manager.history) { item in Text(item.text) }
    }
}
