import SwiftUI

#if compiler(>=6.2)

@available(macOS 26.0, *)
private func makeGlass(_ tint: Color?) -> Glass {
    var g = Glass.regular
    if let tint { g = g.tint(tint) }
    return g
}

extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(makeGlass(tint), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func liquidButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}

struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

#else

extension View {
    func liquidGlass<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        background(.ultraThinMaterial, in: shape)
    }

    @ViewBuilder
    func liquidButton(prominent: Bool = false) -> some View {
        if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}

struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        content
    }
}

#endif
