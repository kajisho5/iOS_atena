import SwiftUI

/// Primary actions placed at the bottom of the screen, within thumb reach on iPhone.
/// Used with `.safeAreaInset(edge: .bottom)` so content scrolls above it.
/// In regular width the buttons hug their labels at the trailing edge, so they stay clear of
/// the fold of iPhone Duo's inner display (Apple: keep interactive elements out of the curve region).
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: horizontalSizeClass == .regular ? nil : 600)
        .frame(maxWidth: .infinity, alignment: horizontalSizeClass == .regular ? .trailing : .center)
        .background {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) { Divider() }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Prominent button label used inside `BottomActionBar`: full width in compact width, label-sized in regular width.
struct PrimaryActionButtonStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 0)
            .frame(maxWidth: horizontalSizeClass == .regular ? nil : .infinity, minHeight: 44)
    }
}

extension View {
    func primaryActionLabel() -> some View {
        modifier(PrimaryActionButtonStyle())
    }

    /// Keyboard handling for forms: a "完了" button above the keyboard and interactive dismissal,
    /// so the keyboard never hides the field being edited or the confirm button in the top bar.
    func formKeyboardSupport(showsNext: Bool, onNext: @escaping () -> Void, onDone: @escaping () -> Void) -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if showsNext {
                        Button("common.keyboardNext", action: onNext)
                    }
                    Spacer()
                    Button("common.keyboardDone", action: onDone)
                        .fontWeight(.semibold)
                }
            }
    }
}
