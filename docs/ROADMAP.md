# Roadmap: Dateroll

## v1.0 — MVP

### Phase 1: Foundation
- [x] Project scaffold (structure, CLAUDE.md, docs)
- [ ] Xcode project creation with Swift 6, iOS 17 target
- [ ] Core models: `DateEntry`, `PhotoAsset`
- [ ] `PhotoLibraryService` — fetch assets, observe changes
- [ ] `DateGroupingService` — group assets by calendar day
- [ ] Unit tests for `DateGroupingService`

### Phase 2: Onboarding
- [ ] `OnboardingView` — welcome + permission request
- [ ] Permission state handling (denied, restricted, limited)
- [ ] `OnboardingViewModel` with permission request flow
- [ ] Empty state view

### Phase 3: Timeline
- [ ] `TimelineView` — scrollable list of `DateEntry` cards
- [ ] `DateCardView` — hero image, date label, photo count
- [ ] `TimelineViewModel` — load & refresh date entries
- [ ] Lazy thumbnail loading via `ImageLoader`
- [ ] Pull-to-refresh

### Phase 4: Date Detail
- [ ] `DateDetailView` — photo grid for a single date
- [ ] Full-screen photo viewer with pinch-to-zoom
- [ ] Swipe navigation between photos
- [ ] Share sheet

### Phase 5: Polish & Release
- [ ] App icon & launch screen
- [ ] Accessibility (Dynamic Type, VoiceOver labels)
- [ ] Performance profiling (large libraries)
- [ ] TestFlight beta
- [ ] App Store submission

---

## v1.1 — Memories
- [ ] Date range / season filter on timeline
- [ ] Auto-generated slideshow per date
- [ ] Custom date label / notes
- [ ] "On this day" local notification

## v1.2 — Sharing
- [ ] Export date as photo collage
- [ ] Share full date as album link
- [ ] Home screen widget (most recent date)

## v2.0 — Couples
- [ ] Partner profile tagging
- [ ] Couple stats (total dates, longest streak, etc.)
- [ ] Anniversary reminders
