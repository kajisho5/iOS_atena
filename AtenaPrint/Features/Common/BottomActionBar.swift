import SwiftUI

/// Primary actions placed at the bottom of the screen, within thumb reach on iPhone.
/// Used with `.safeAreaInset(edge: .bottom)` so content scrolls above it.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) { Divider() }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Full-width prominent button used inside `BottomActionBar`.
struct PrimaryActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

extension View {
    func primaryActionLabel() -> some View {
        modifier(PrimaryActionButtonStyle())
    }

    /// Keyboard handling for forms: a "完了" button above the keyboard and interactive dismissal,
    /// so the keyboard never hides the field being edited or the confirm button in the top bar.
    func formKeyboardSupport(onNext: (() -> Void)?, onDone: @escaping () -> Void) -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if let onNext {
                        Button("common.keyboardNext", action: onNext)
                    }
                    Spacer()
                    Button("common.keyboardDone", action: onDone)
                        .fontWeight(.semibold)
                }
            }
    }
}
