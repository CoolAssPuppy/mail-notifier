import SwiftUI

/// A compact theme chooser that keeps the selected color at the row's right edge.
struct ThemeSelector: View {
    @Binding var selection: AppTheme

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var isReduceMotionEnabled
    @State private var isExpanded = false
    @State private var isPinned = false
    @FocusState private var isTriggerFocused: Bool
    @FocusState private var focusedOption: AppTheme?
    @Namespace private var circleTransition

    private var transition: Animation? {
        isReduceMotionEnabled ? nil : .spring(response: 0.36, dampingFraction: 0.8)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(selection.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.foreground)
                .id(selection)
                .transition(.opacity)

            if isExpanded {
                HStack(spacing: 6) {
                    ForEach(AppTheme.allCases.filter { $0 != selection }) { option in
                        Button {
                            withAnimation(transition) {
                                selection = option
                                isExpanded = false
                            }
                            isPinned = false
                            focusedOption = nil
                            isTriggerFocused = true
                        } label: {
                            themeCircle(for: option)
                                .matchedGeometryEffect(id: option.id, in: circleTransition)
                                .overlay {
                                    Circle()
                                        .strokeBorder(theme.primary, lineWidth: focusedOption == option ? 2 : 0)
                                        .padding(1)
                                }
                        }
                        .buttonStyle(.plain)
                        .focused($focusedOption, equals: option)
                        .help(option.label)
                        .accessibilityLabel(option.label)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.75, anchor: .trailing)))
            }

            Button {
                isPinned = !isPinned
                withAnimation(transition) { isExpanded = isPinned }
                if isPinned {
                    Task { @MainActor in focusedOption = AppTheme.allCases.first { $0 != selection } }
                } else {
                    focusedOption = nil
                }
            } label: {
                themeCircle(for: selection)
                    .matchedGeometryEffect(id: selection.id, in: circleTransition)
                    .overlay {
                        Circle()
                            .strokeBorder(theme.primary, lineWidth: isTriggerFocused ? 2 : 0)
                            .padding(1)
                    }
            }
            .buttonStyle(.plain)
            .focused($isTriggerFocused)
            .help(selection.label)
            .accessibilityLabel("Theme")
            .accessibilityValue(selection.label)
            .onHover { isHovering in
                if isHovering && !isExpanded {
                    withAnimation(transition) { isExpanded = true }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onHover { isHovering in
            if !isHovering && !isPinned && focusedOption == nil && isExpanded {
                withAnimation(transition) { isExpanded = false }
            }
        }
        .onChange(of: focusedOption) { _, option in
            if option != nil { isPinned = true }
        }
        .onKeyPress(.escape) {
            guard isExpanded else { return .ignored }
            isPinned = false
            focusedOption = nil
            isTriggerFocused = true
            withAnimation(transition) { isExpanded = false }
            return .handled
        }
    }

    @ViewBuilder
    private func themeCircle(for option: AppTheme) -> some View {
        ZStack {
            if option == .system {
                Circle()
                    .fill(.white)
                    .overlay(alignment: .trailing) {
                        Circle().fill(.black).mask(alignment: .trailing) {
                            Rectangle().frame(width: 10)
                        }
                    }
            } else {
                Circle()
                    .fill(LinearGradient(colors: [option.palette.primary, option.palette.primaryDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .frame(width: 20, height: 20)
        .overlay(Circle().strokeBorder(theme.borderStrong, lineWidth: 1))
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    }
}
