# Misc

- The app is designed for mobile, tablet and desktop so it should be responsive.
- Once you finish an implementation task prompt me using the question/prompt tool to review it and in the options for the prompt have good, medium, bad and other. Every time even if you previously prompted me do it again.
- Before running tests run static analyzers

# Frontend Design

## StatefulWidget Performance Guidelines

Use `StatefulWidget` only when UI must change dynamically. Keep widgets efficient by following these rules:

**State placement**

- Push mutable state as deep in the tree as possible.
- Avoid placing frequently changing state high in the widget tree.
- Prefer small stateful leaf widgets instead of rebuilding large parents.

**Rebuild cost**

- Minimize widgets created inside `build()`.
- Extract static parts into separate widgets.
- Cache unchanged subtrees in `final` variables.
- Use `const` constructors whenever possible.

**Structure stability**

- Avoid changing widget types or tree depth between rebuilds.
- Prefer changing properties instead of conditionally wrapping widgets.
- Use keys, especially `GlobalKey`, only when state must be preserved across moves.

**Lifecycle**

- Allocate resources in `initState()`.
- Dispose resources in `dispose()`.
- Call `setState()` only when UI must update.

**Design principles**

- `StatefulWidget` is immutable. Mutable data belongs in `State`.
- Prefer `StatelessWidget` when UI depends only on inputs and context.
- Keep rebuild frequency and scope as small as possible.

**Rule of thumb**
A well designed `StatefulWidget` updates only the minimal part of the UI and avoids unnecessary rebuilds.

## Design System Architecture

The app uses a layered, fully configurable design system in `lib/ui/core/theme.dart`.

**Core types:**

- `SenpwaiColorSet` — one mode's colors (primary, secondary, tertiary, background, surface, surfaceVariant, onSurface, onPrimary, error).
- `SenpwaiColors` — wraps a `dark` and `light` `SenpwaiColorSet`. Every preset provides hand-crafted colors for both modes.
- `SenpwaiTypography` — display/body font families, all size/weight tokens from display through body. Has a `neon` static preset.
- `SenpwaiShapeStyle` — cardRadius, cardBorderWidth, inputRadius, buttonRadius. Has a `neon` static preset.
- `SenpwaiTheme` — composes `SenpwaiColors` + `SenpwaiTypography` + `SenpwaiShapeStyle`. Has `toThemeData(Brightness)` that builds a full `ThemeData` for the given brightness (dark or light) using the matching `SenpwaiColorSet`.
- `SenpwaiThemePreset` — enum of curated full themes (defaultTheme, gruvbox, dracula, catppuccin, monokai). Each has `toTheme()` returning a complete `SenpwaiTheme` with specialized colors, typography, and shapes.
- `ThemeConfig` — `ChangeNotifier` holding ONE `SenpwaiTheme` + `BrightnessMode` + optional active preset. `applyPreset()` applies the full theme (colors + typography + shapes). Exposes `buildLightTheme()` / `buildDarkTheme()` for `MaterialApp`.
- `ThemeConfigProvider` — `InheritedNotifier` that provides `ThemeConfig` via `ThemeConfigProvider.of(context)`.
- `SenpwaiThemeExtension` — `ThemeExtension` on `ThemeData` for card styling and shimmer. Badge/score colors are derived from the existing `ColorScheme` (surface, onSurface, secondary) — NOT separate fields.

**Font picker** uses `displayFontOptions` and `bodyFontOptions` lists of `FontOption`. Settings page exposes dropdowns that update `config.typography`.

**Pagination** uses `PaginatedScrollMixin` from `lib/ui/core/pagination.dart` — mix into any `State` to get infinite scroll with configurable threshold.

**Key rules:**

- Never auto-adapt colors from dark to light. Each preset provides explicit hand-crafted dark and light color sets.
- Brightness is always passed explicitly to `toThemeData(Brightness)`, never inferred from color luminance.
- `ThemeConfig` holds a single `SenpwaiTheme` (not separate dark/light themes).

name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt

---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.

## Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:

- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is:

- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

## Frontend Aesthetics Guidelines

Focus on:

- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics; unexpected, characterful font choices. Pair a distinctive display font with a refined body font.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions. Use scroll-triggering and hover states that surprise.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects and textures that match the overall aesthetic. Apply creative forms like gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, and grain overlays.

NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character.

Interpret creatively and make unexpected choices that feel genuinely designed for the context. No design should be the same. Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on common choices (Space Grotesk, for example) across generations.

**IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details. Elegance comes from executing the vision well.

Remember: You are capable of extraordinary creative work. Don't hold back, show what can truly be created when thinking outside the box and committing fully to a distinctive vision.
