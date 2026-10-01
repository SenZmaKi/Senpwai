# Website analytics

The shared layout loads Umami only in production. `src/lib/analytics.ts`
records deliberate interactions, using Umami's own session tracking to connect
page visits and events. No separate visitor ID or journey storage is added.

Every interaction includes `source_page` (`home`, `downloads`, or `legal`),
`source_path`, `location` (hero, desktop/mobile navigation, footer, community
section, download card, showcase, themes, or content), and `control`.
Pageviews record actual page arrivals; navigation events record intent.

| Event | Meaning | Additional properties |
| --- | --- | --- |
| `download-page-click` | Navigate to Downloads | destination, destination_path |
| `page-navigation` | Navigate to Home or Legal | destination, destination_path |
| `section-click` | Navigate to a page section | section, destination, destination_path |
| `download-click` | Open a GitHub release asset | platform, architecture, version, destination, destination_type |
| `repository-click` | Open the source repository | destination, destination_type |
| `releases-click` | Browse GitHub releases | destination, destination_type |
| `support-click` | Open GitHub issues | destination, destination_type |
| `community-click` | Open Discord or Reddit | destination, destination_type |
| `outbound-click` | Open another external destination | destination, destination_type |
| `macos-help-open` | Open Gatekeeper instructions | platform |
| `showcase-select` | Manually select an app screenshot | screen |
| `theme-select` | Manually select a theme preview | theme |

## Suggested reports

Configure these in the analytics dashboard after deploying:

- Download goal: triggered event `download-click`.
- Community goal: triggered event `community-click`; compare `destination_type`.
- Support usage: triggered event `support-click` or `macos-help-open`.
- Download funnel: viewed `/` → viewed `/download` → triggered `download-click`.
- CTA funnel: triggered `download-page-click` → viewed `/download` → triggered
  `download-click`. Compare the first event's `location` to assess CTA placements.
- Product exploration: viewed `/` → triggered `showcase-select` (or
  `theme-select`) → viewed `/download` → triggered `download-click`.
- Journey exploration: start at `/` or `/download` and include both pageviews
  and custom events. Direct arrivals at Downloads need not visit Home first.

Actual report controls depend on the installed Umami version. Event-property
breakdowns and filters may be separate from funnel step configuration.

## Measurement boundaries

Downloads are clicks, not completed downloads or installations. Community and
support events are outbound intent, not confirmed joins or submitted issues.
Section clicks do not prove a section was read. Automatic carousel rotations
are excluded. External URL query strings and hashes are excluded from custom
destination properties. Blocked or unavailable analytics never delays navigation;
those visits and interactions can be absent from reports. Local production
previews also enable tracking; `astro dev` does not.

Live delivery and session continuity must be verified after deployment. These
changes do not create reports in the dashboard or backfill historical events.
