# SeleneChat Forest Study Redesign - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform SeleneChat's visual design from generic SwiftUI to the Forest Study design system — an earthy, calm + sharp aesthetic.

**Architecture:** Create a centralized Design/ module with colors, typography, and spacing constants. Build reusable components that use these design tokens. Migrate existing views to use the new design system one at a time, keeping the app functional throughout.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14+, SF Pro (system), Charter (serif)

**Design Reference:** `docs/plans/2026-01-05-selenechat-redesign-design.md`

---

## Phase 1: Design System Foundation

### Task 1: Create Color Palette

**Files:**
- Create: `SeleneChat/Sources/Design/Colors.swift`

**Step 1: Create the Design directory**

```bash
mkdir -p SeleneChat/Sources/Design
```

**Step 2: Create Colors.swift with the Forest Study palette**

```swift
// SeleneChat/Sources/Design/Colors.swift
import SwiftUI

extension Color {
    // MARK: - Backgrounds

    /// Primary background - warm cream (#FAF8F5)
    static let canvas = Color(red: 250/255, green: 248/255, blue: 245/255)

    /// Cards and panels - soft linen (#F3F0EA)
    static let surface = Color(red: 243/255, green: 240/255, blue: 234/255)

    /// Focused content - paper white (#FFFEFA)
    static let elevated = Color(red: 255/255, green: 254/255, blue: 250/255)

    // MARK: - Borders & Dividers

    /// Subtle lines - warm sand (#E5DED3)
    static let border = Color(red: 229/255, green: 222/255, blue: 211/255)

    /// Section breaks - lighter sand (#EBE6DC)
    static let divider = Color(red: 235/255, green: 230/255, blue: 220/255)

    // MARK: - Text

    /// Headlines and body - deep earth (#2C2416)
    static let textPrimary = Color(red: 44/255, green: 36/255, blue: 22/255)

    /// Captions and muted - warm gray (#6B5F4F)
    static let textSecondary = Color(red: 107/255, green: 95/255, blue: 79/255)

    /// Timestamps and hints - faded earth (#9A8F7F)
    static let textTertiary = Color(red: 154/255, green: 143/255, blue: 127/255)

    // MARK: - Accents

    /// Actions and focus - forest sage (#4A6741)
    static let accentSage = Color(red: 74/255, green: 103/255, blue: 65/255)

    /// Links and info - muted blue (#5B7C8A)
    static let accentBlue = Color(red: 91/255, green: 124/255, blue: 138/255)

    /// Energy and alerts - terracotta (#B5694D)
    static let accentTerracotta = Color(red: 181/255, green: 105/255, blue: 77/255)

    /// Confirmations - moss green (#5A7C5A)
    static let accentMoss = Color(red: 90/255, green: 124/255, blue: 90/255)

    // MARK: - Semantic Colors

    /// User message background (sage at 10%)
    static let userMessageBackground = Color.accentSage.opacity(0.1)
}
```

**Step 3: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds or shows unrelated warnings

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Design/Colors.swift
git commit -m "feat(design): add Forest Study color palette"
```

---

### Task 2: Create Typography System

**Files:**
- Create: `SeleneChat/Sources/Design/Typography.swift`

**Step 1: Create Typography.swift with font definitions**

```swift
// SeleneChat/Sources/Design/Typography.swift
import SwiftUI

extension Font {
    // MARK: - Reading (Serif)
    // Charter is available on macOS by default

    /// Note body text - Charter 15px
    static let readingBody = Font.custom("Charter", size: 15)

    /// Note title - Charter 17px semibold
    static let readingTitle = Font.custom("Charter", size: 17).weight(.semibold)

    /// Blockquote - Charter 15px italic
    static let readingQuote = Font.custom("Charter", size: 15).italic()

    /// Reading caption - Charter 14px
    static let readingCaption = Font.custom("Charter", size: 14)

    // MARK: - UI (Sans-serif)
    // SF Pro is the system font

    /// Page title - 18px semibold
    static let uiPageTitle = Font.system(size: 18, weight: .semibold)

    /// Section header - 14px semibold
    static let uiSectionHeader = Font.system(size: 14, weight: .semibold)

    /// Labels - 13px medium
    static let uiLabel = Font.system(size: 13, weight: .medium)

    /// Captions - 11px regular
    static let uiCaption = Font.system(size: 11, weight: .regular)

    /// Buttons - 13px medium
    static let uiButton = Font.system(size: 13, weight: .medium)

    // MARK: - Monospace (Data)

    /// Timestamps - 11px monospace
    static let monoTimestamp = Font.system(size: 11, design: .monospaced)

    /// Codes/IDs - 12px monospace
    static let monoCode = Font.system(size: 12, design: .monospaced)
}

// MARK: - View Modifiers for Typography

extension View {
    /// Apply reading body style (Charter 15px, primary color)
    func readingBodyStyle() -> some View {
        self
            .font(.readingBody)
            .foregroundColor(.textPrimary)
            .lineSpacing(4) // 1.6 line height approximation
    }

    /// Apply reading title style (Charter 17px semibold)
    func readingTitleStyle() -> some View {
        self
            .font(.readingTitle)
            .foregroundColor(.textPrimary)
    }

    /// Apply section header style (SF Pro 11px uppercase)
    func sectionHeaderStyle() -> some View {
        self
            .font(.uiCaption)
            .fontWeight(.semibold)
            .foregroundColor(.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Design/Typography.swift
git commit -m "feat(design): add typography system with Charter serif"
```

---

### Task 3: Create Spacing Constants

**Files:**
- Create: `SeleneChat/Sources/Design/Spacing.swift`

**Step 1: Create Spacing.swift with the 4px grid**

```swift
// SeleneChat/Sources/Design/Spacing.swift
import SwiftUI

/// Spacing constants based on 4px grid
enum Spacing {
    /// 4px - micro spacing (icon gaps)
    static let micro: CGFloat = 4

    /// 8px - tight spacing (within components)
    static let tight: CGFloat = 8

    /// 12px - standard spacing (between related elements)
    static let standard: CGFloat = 12

    /// 16px - comfortable spacing (section padding)
    static let comfortable: CGFloat = 16

    /// 24px - generous spacing (between sections)
    static let generous: CGFloat = 24

    /// 32px - major separation
    static let major: CGFloat = 32
}

/// Corner radius constants
enum CornerRadius {
    /// 4px - small elements
    static let small: CGFloat = 4

    /// 6px - buttons, inputs, cards
    static let medium: CGFloat = 6

    /// 8px - larger cards
    static let large: CGFloat = 8

    /// 12px - message bubbles
    static let bubble: CGFloat = 12
}

/// Layout constants
enum Layout {
    /// List panel width
    static let listPanelWidth: CGFloat = 280

    /// Minimum detail panel width
    static let detailPanelMinWidth: CGFloat = 400

    /// Left accent bar width for selected items
    static let accentBarWidth: CGFloat = 3
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Design/Spacing.swift
git commit -m "feat(design): add spacing and layout constants"
```

---

## Phase 2: Core Components

### Task 4: Create ForestButton Component

**Files:**
- Create: `SeleneChat/Sources/Design/Components/ForestButton.swift`

**Step 1: Create Components directory**

```bash
mkdir -p SeleneChat/Sources/Design/Components
```

**Step 2: Create ForestButton.swift**

```swift
// SeleneChat/Sources/Design/Components/ForestButton.swift
import SwiftUI

enum ForestButtonStyle {
    case primary    // Sage background, white text
    case secondary  // Transparent, border, dark text
    case ghost      // Transparent, no border, muted text
}

struct ForestButton: View {
    let title: String
    let icon: String?
    let style: ForestButtonStyle
    let action: () -> Void

    @State private var isHovered = false

    init(
        _ title: String,
        icon: String? = nil,
        style: ForestButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
                Text(title)
                    .font(.uiButton)
            }
            .padding(.horizontal, Spacing.comfortable)
            .padding(.vertical, Spacing.tight)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1 : 0)
            )
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovered ? Color.accentSage.opacity(0.85) : Color.accentSage
        case .secondary:
            return isHovered ? Color.surface : Color.clear
        case .ghost:
            return Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color.elevated
        case .secondary:
            return Color.textPrimary
        case .ghost:
            return isHovered ? Color.textPrimary : Color.textSecondary
        }
    }

    private var borderColor: Color {
        style == .secondary ? Color.border : Color.clear
    }
}

#Preview("Forest Buttons") {
    VStack(spacing: 16) {
        ForestButton("Primary Action", icon: "plus", style: .primary) {}
        ForestButton("Secondary", style: .secondary) {}
        ForestButton("Ghost Button", style: .ghost) {}
    }
    .padding(32)
    .background(Color.canvas)
}
```

**Step 3: Verify it compiles and preview works**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Design/Components/ForestButton.swift
git commit -m "feat(design): add ForestButton component"
```

---

### Task 5: Create ForestCard Component

**Files:**
- Create: `SeleneChat/Sources/Design/Components/ForestCard.swift`

**Step 1: Create ForestCard.swift**

```swift
// SeleneChat/Sources/Design/Components/ForestCard.swift
import SwiftUI

struct ForestCard<Content: View>: View {
    let isSelected: Bool
    let accentColor: Color?
    let content: Content

    init(
        isSelected: Bool = false,
        accentColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar when selected or colored
            if let color = effectiveAccentColor {
                Rectangle()
                    .fill(color)
                    .frame(width: Layout.accentBarWidth)
            }

            content
                .padding(Spacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(isSelected ? Color.elevated : Color.surface)
        .cornerRadius(CornerRadius.medium)
    }

    private var effectiveAccentColor: Color? {
        if isSelected {
            return accentColor ?? Color.accentSage
        }
        return accentColor
    }
}

#Preview("Forest Cards") {
    VStack(spacing: Spacing.tight) {
        ForestCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Regular Card")
                    .font(.readingTitle)
                Text("Some content here")
                    .font(.readingCaption)
                    .foregroundColor(.textSecondary)
            }
        }

        ForestCard(isSelected: true) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Card")
                    .font(.readingTitle)
                Text("With sage accent bar")
                    .font(.readingCaption)
                    .foregroundColor(.textSecondary)
            }
        }

        ForestCard(accentColor: .accentTerracotta) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Inbox Item")
                    .font(.readingTitle)
                Text("Needs triage")
                    .font(.readingCaption)
                    .foregroundColor(.textSecondary)
            }
        }
    }
    .padding(Spacing.comfortable)
    .background(Color.canvas)
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Design/Components/ForestCard.swift
git commit -m "feat(design): add ForestCard component"
```

---

### Task 6: Create ForestInput Component

**Files:**
- Create: `SeleneChat/Sources/Design/Components/ForestInput.swift`

**Step 1: Create ForestInput.swift**

```swift
// SeleneChat/Sources/Design/Components/ForestInput.swift
import SwiftUI

struct ForestInput: View {
    let placeholder: String
    @Binding var text: String
    let isChat: Bool
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        isChat: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isChat = isChat
        self.onSubmit = onSubmit
    }

    var body: some View {
        TextField(placeholder, text: $text, axis: isChat ? .vertical : .horizontal)
            .font(isChat ? .readingBody : .system(size: 14))
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, isChat ? Spacing.standard : 10)
            .background(Color.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: isChat ? CornerRadius.large : CornerRadius.medium)
                    .stroke(isFocused ? Color.accentSage : Color.border, lineWidth: 1)
            )
            .cornerRadius(isChat ? CornerRadius.large : CornerRadius.medium)
            .focused($isFocused)
            .onSubmit {
                onSubmit?()
            }
    }
}

#Preview("Forest Inputs") {
    VStack(spacing: 16) {
        ForestInput("Regular input", text: .constant(""))
        ForestInput("Chat input with longer placeholder", text: .constant(""), isChat: true)
        ForestInput("With text", text: .constant("Some typed text"))
    }
    .padding(32)
    .background(Color.canvas)
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Design/Components/ForestInput.swift
git commit -m "feat(design): add ForestInput component"
```

---

### Task 7: Create ForestSectionHeader Component

**Files:**
- Create: `SeleneChat/Sources/Design/Components/ForestSectionHeader.swift`

**Step 1: Create ForestSectionHeader.swift**

```swift
// SeleneChat/Sources/Design/Components/ForestSectionHeader.swift
import SwiftUI

struct ForestSectionHeader: View {
    let title: String
    let icon: String?
    let count: Int?
    let isExpanded: Bool
    let iconColor: Color
    let badgeColor: Color?
    let onToggle: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        count: Int? = nil,
        isExpanded: Bool = true,
        iconColor: Color = .textTertiary,
        badgeColor: Color? = nil,
        onToggle: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.isExpanded = isExpanded
        self.iconColor = iconColor
        self.badgeColor = badgeColor
        self.onToggle = onToggle
    }

    var body: some View {
        Button(action: { withAnimation(.easeOut(duration: 0.15)) { onToggle() } }) {
            HStack(spacing: Spacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .sectionHeaderStyle()

                if let count = count {
                    Text("\(count)")
                        .font(.uiCaption)
                        .fontWeight(.medium)
                        .foregroundColor(badgeColor != nil ? .elevated : .textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor ?? Color.clear)
                        .cornerRadius(CornerRadius.small)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, Spacing.comfortable)
            .padding(.vertical, Spacing.standard)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Section Headers") {
    VStack(spacing: 0) {
        ForestSectionHeader(
            "Active Projects",
            icon: "star.fill",
            isExpanded: true,
            iconColor: .accentSage
        ) {}

        Divider()

        ForestSectionHeader(
            "Inbox",
            icon: "tray",
            count: 4,
            isExpanded: true,
            iconColor: .accentTerracotta,
            badgeColor: .accentTerracotta
        ) {}

        Divider()

        ForestSectionHeader(
            "Parked",
            icon: "moon.zzz",
            isExpanded: false
        ) {}
    }
    .background(Color.surface)
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Design/Components/ForestSectionHeader.swift
git commit -m "feat(design): add ForestSectionHeader component"
```

---

### Task 8: Create ForestMessageBubble Component

**Files:**
- Create: `SeleneChat/Sources/Design/Components/ForestMessageBubble.swift`

**Step 1: Create ForestMessageBubble.swift**

```swift
// SeleneChat/Sources/Design/Components/ForestMessageBubble.swift
import SwiftUI

enum MessageRole {
    case user
    case assistant
    case system
}

struct ForestMessageBubble: View {
    let content: String
    let role: MessageRole
    let timestamp: String?
    let providerLabel: String?

    init(
        _ content: String,
        role: MessageRole,
        timestamp: String? = nil,
        providerLabel: String? = nil
    ) {
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.providerLabel = providerLabel
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.standard) {
            if role == .user { Spacer(minLength: 60) }

            VStack(alignment: role == .user ? .trailing : .leading, spacing: Spacing.micro) {
                // Message content
                Text(content)
                    .font(.readingBody)
                    .foregroundColor(role == .user ? .textPrimary : .textPrimary)
                    .padding(.horizontal, Spacing.comfortable)
                    .padding(.vertical, Spacing.standard)
                    .background(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.bubble)
                            .stroke(role == .assistant ? Color.border : Color.clear, lineWidth: 1)
                    )
                    .clipShape(bubbleShape)

                // Metadata row
                HStack(spacing: Spacing.tight) {
                    if let provider = providerLabel, role == .assistant {
                        Text(provider)
                            .font(.uiCaption)
                            .foregroundColor(.textTertiary)
                    }

                    if let time = timestamp {
                        Text(time)
                            .font(.monoTimestamp)
                            .foregroundColor(.textTertiary)
                    }
                }
            }
            .frame(maxWidth: role == .user ? nil : .infinity * 0.85, alignment: role == .user ? .trailing : .leading)

            if role != .user { Spacer(minLength: 40) }
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .user:
            return Color.userMessageBackground
        case .assistant:
            return Color.elevated
        case .system:
            return Color.accentTerracotta.opacity(0.1)
        }
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: CornerRadius.bubble)
    }
}

#Preview("Message Bubbles") {
    VStack(spacing: Spacing.comfortable) {
        ForestMessageBubble(
            "What are my notes about home renovation?",
            role: .user,
            timestamp: "2:34 PM"
        )

        ForestMessageBubble(
            "Based on your notes, you've been thinking about kitchen cabinets and whether to go with IKEA or custom. You mentioned needing to measure the space first [1].",
            role: .assistant,
            timestamp: "2:34 PM",
            providerLabel: "Local"
        )

        ForestMessageBubble(
            "Connection lost. Retrying...",
            role: .system
        )
    }
    .padding(Spacing.comfortable)
    .background(Color.canvas)
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Design/Components/ForestMessageBubble.swift
git commit -m "feat(design): add ForestMessageBubble component"
```

---

### Task 9: Create ThinkingIndicator Redesign

**Files:**
- Modify: `SeleneChat/Sources/Views/ThinkingIndicator.swift`

**Step 1: Read current implementation**

Run: `cat SeleneChat/Sources/Views/ThinkingIndicator.swift`

**Step 2: Replace with Forest Study version**

```swift
// SeleneChat/Sources/Views/ThinkingIndicator.swift
import SwiftUI

struct ThinkingIndicator: View {
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.accentSage)
                    .frame(width: 6, height: 6)
                    .opacity(dotOpacities[index])
            }

            Text("Thinking...")
                .font(.uiLabel)
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.tight)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Staggered fade animation
        for i in 0..<3 {
            let delay = Double(i) * 0.15
            withAnimation(
                Animation
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
            ) {
                dotOpacities[i] = 1.0
            }
        }
    }
}

#Preview("Thinking Indicator") {
    VStack {
        ThinkingIndicator()
    }
    .padding(32)
    .background(Color.canvas)
}
```

**Step 3: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Views/ThinkingIndicator.swift
git commit -m "refactor(design): update ThinkingIndicator to Forest Study style"
```

---

## Phase 3: View Migration - ContentView Shell

### Task 10: Update ContentView with New Layout

**Files:**
- Modify: `SeleneChat/Sources/App/ContentView.swift`

**Step 1: Read current implementation**

Run: `cat SeleneChat/Sources/App/ContentView.swift`

**Step 2: Update to Forest Study layout**

```swift
// SeleneChat/Sources/App/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedView: NavigationItem = .threads
    @EnvironmentObject var databaseService: DatabaseService

    enum NavigationItem: String, CaseIterable {
        case threads = "Threads"
        case search = "Search"
        case chat = "Chat"

        var icon: String {
            switch self {
            case .threads: return "list.bullet.rectangle"
            case .search: return "magnifyingglass"
            case .chat: return "bubble.left.and.bubble.right"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            topNavigationBar

            Divider()
                .background(Color.border)

            // Main content
            switch selectedView {
            case .threads:
                PlanningView()
            case .search:
                SearchView()
            case .chat:
                ChatView()
            }
        }
        .background(Color.canvas)
        .onAppear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Appeared: ContentView")
            ActionTracker.shared.track(action: "viewAppeared", params: ["view": "ContentView"])
            #endif
        }
        .onDisappear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Disappeared: ContentView")
            #endif
        }
    }

    private var topNavigationBar: some View {
        HStack(spacing: Spacing.generous) {
            // App title
            Text("Selene")
                .font(.uiPageTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            // Mode tabs
            HStack(spacing: Spacing.micro) {
                ForEach(NavigationItem.allCases, id: \.self) { item in
                    modeTab(item)
                }
            }

            Spacer()

            // Placeholder for settings/actions
            Color.clear
                .frame(width: 60)
        }
        .padding(.horizontal, Spacing.comfortable)
        .padding(.vertical, Spacing.standard)
        .background(Color.surface)
    }

    private func modeTab(_ item: NavigationItem) -> some View {
        Button(action: { selectedView = item }) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                Text(item.rawValue)
                    .font(.uiLabel)
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.tight)
            .foregroundColor(selectedView == item ? Color.accentSage : Color.textSecondary)
            .background(
                selectedView == item
                    ? Color.accentSage.opacity(0.1)
                    : Color.clear
            )
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
```

**Step 3: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds (may have warnings about missing EnvironmentObject in preview)

**Step 4: Commit**

```bash
git add SeleneChat/Sources/App/ContentView.swift
git commit -m "refactor(design): update ContentView to Forest Study layout"
```

---

## Phase 4: View Migration - ChatView

### Task 11: Update ChatView Header

**Files:**
- Modify: `SeleneChat/Sources/Views/ChatView.swift`

**Step 1: Read current ChatView**

Run: `cat SeleneChat/Sources/Views/ChatView.swift | head -80`

**Step 2: Update chatHeader to Forest Study style**

Find the `chatHeader` computed property and replace with:

```swift
private var chatHeader: some View {
    HStack {
        VStack(alignment: .leading, spacing: Spacing.micro) {
            Text(chatViewModel.currentSession.title)
                .font(.uiSectionHeader)
                .foregroundColor(.textPrimary)

            HStack(spacing: Spacing.micro) {
                Circle()
                    .fill(databaseService.isConnected ? Color.accentMoss : Color.accentTerracotta)
                    .frame(width: 6, height: 6)

                Text(databaseService.isConnected ? "Connected to Selene" : "Database disconnected")
                    .font(.uiCaption)
                    .foregroundColor(.textTertiary)
            }
        }

        Spacer()

        ForestButton("History", icon: "clock.arrow.circlepath", style: .ghost) {
            showingSessionHistory = true
        }

        ForestButton("New Chat", icon: "plus.message", style: .secondary) {
            chatViewModel.newSession()
        }
    }
    .padding(Spacing.comfortable)
    .background(Color.surface)
}
```

**Step 3: Update chatInput to Forest Study style**

Find the `chatInput` computed property and replace with:

```swift
private var chatInput: some View {
    HStack(alignment: .bottom, spacing: Spacing.standard) {
        ForestInput("Ask about your notes...", text: $messageText, isChat: true) {
            sendMessage()
        }
        .disabled(chatViewModel.isProcessing)

        Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(messageText.isEmpty ? Color.textTertiary : Color.accentSage)
        }
        .buttonStyle(.plain)
        .disabled(messageText.isEmpty || chatViewModel.isProcessing)
    }
    .padding(Spacing.comfortable)
    .background(Color.surface)
}
```

**Step 4: Update body background**

In the main `body`, wrap the VStack with:

```swift
var body: some View {
    VStack(spacing: 0) {
        // ... existing content
    }
    .background(Color.canvas)
    // ... rest of modifiers
}
```

**Step 5: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -30`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add SeleneChat/Sources/Views/ChatView.swift
git commit -m "refactor(design): update ChatView to Forest Study style"
```

---

### Task 12: Update MessageBubble in ChatView

**Files:**
- Modify: `SeleneChat/Sources/Views/ChatView.swift`

**Step 1: Find and update MessageBubble struct**

The MessageBubble struct is defined in ChatView.swift. Update its colors:

Replace `backgroundColor` computed property:

```swift
private var backgroundColor: Color {
    switch message.role {
    case .user:
        return Color.userMessageBackground
    case .assistant:
        return Color.elevated
    case .system:
        return Color.accentTerracotta.opacity(0.15)
    }
}
```

Replace `textColor` computed property:

```swift
private var textColor: Color {
    Color.textPrimary
}
```

Update the message content Text view to use Charter:

```swift
Group {
    if let attributedContent = message.attributedContent {
        Text(attributedContent)
            .font(.readingBody)
            // ... rest unchanged
    } else {
        Text(message.content)
            .font(.readingBody)
    }
}
```

Update the cornerRadius in the content modifier:

```swift
.cornerRadius(CornerRadius.bubble)
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/ChatView.swift
git commit -m "refactor(design): update MessageBubble to Forest Study style"
```

---

## Phase 5: Integration Testing

### Task 13: Build and Visual Test

**Step 1: Full build**

Run: `cd SeleneChat && swift build -c release 2>&1`
Expected: Build succeeds with no errors

**Step 2: Run the app**

Run: `cd SeleneChat && swift run &`

**Step 3: Manual verification checklist**

- [ ] App launches with cream background
- [ ] Top navigation shows Threads/Search/Chat tabs
- [ ] Sage green is used for primary actions
- [ ] Message bubbles use Charter serif font
- [ ] Thinking indicator shows sage dots
- [ ] Cards have no shadows, only surface color differences

**Step 4: Commit integration milestone**

```bash
git add -A
git commit -m "feat(design): complete Forest Study design system integration

Phase 1-5 complete:
- Color palette (cream, sage, terracotta, blue)
- Typography (Charter serif for reading, SF Pro for UI)
- Spacing constants (4px grid)
- Core components (Button, Card, Input, SectionHeader, MessageBubble)
- ContentView and ChatView migrations
"
```

---

## Remaining View Migrations (Future Tasks)

The following views need migration in subsequent tasks:

1. **PlanningView.swift** - Apply ForestSectionHeader, ForestCard
2. **SearchView.swift** - Apply ForestInput, ForestCard
3. **ProjectDetailView.swift** - Apply typography and colors
4. **SettingsView.swift** - Apply form styling
5. **Planning/* components** - Update all Planning subviews

Each follows the same pattern:
1. Read current implementation
2. Update colors to use Color extensions
3. Update fonts to use Font extensions
4. Replace buttons with ForestButton
5. Replace cards with ForestCard
6. Test and commit

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-3 | Design system foundation (colors, typography, spacing) |
| 2 | 4-9 | Core components (button, card, input, header, bubble, indicator) |
| 3 | 10 | ContentView shell migration |
| 4 | 11-12 | ChatView migration |
| 5 | 13 | Integration testing |

**Total estimated tasks in this plan:** 13
**Remaining views for future plans:** 10+ files
