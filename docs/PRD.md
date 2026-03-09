# PRD: Dateroll

## Overview
Dateroll is an iOS app for couples that transforms a shared photo library into a romantic timeline of "dates" — days the couple spent together, inferred from photo metadata. Each date is a curated collection of photos from that day, presented in a warm, memory-book style.

## Problem
Couples accumulate hundreds of photos together but have no easy way to relive them by occasion. Scrolling the camera roll by date is tedious and loses the emotional context of individual outings.

## Target Users
- Couples (any relationship type) who share an iCloud photo library or regularly share photos with each other
- Users on iOS 17+

## Core Features

### MVP (v1.0)

#### 1. Photo Library Access & Permission
- Request photo library access on first launch
- Handle all permission states: not determined, authorised, denied, restricted, limited
- Show meaningful onboarding explaining why access is needed
- Support limited photo library selection

#### 2. Timeline View (Home)
- Display a chronological (newest-first) list of "dates" — days with ≥1 photo
- Each date card shows:
  - Date label (e.g. "Saturday, 14 Feb 2025")
  - Lead/hero photo (highest-quality thumbnail)
  - Photo count badge
  - Optional: location label if available from EXIF
- Smooth infinite scroll with lazy loading
- Pull-to-refresh to re-sync library

#### 3. Date Detail View
- Full-screen photo grid for a selected date
- Tap a photo to view full-screen with pinch-to-zoom
- Swipe left/right to navigate photos within the date
- Share sheet for individual photos or the full date collection
- Display metadata: time range of photos, location if available

#### 4. Onboarding
- Welcome screen introducing the concept
- Photo permission request with clear explanation
- Empty state if no photos found

### Post-MVP (v1.1+)
- Filtering by date range or season
- "Memory" style auto-generated slideshows per date
- Couple profiles / partner tagging
- Custom date labels / notes
- Export date as a photo collage
- Widgets (Today's anniversary, Recent dates)
- Notification reminders ("On this day")

## Non-Goals (v1.0)
- Social sharing or cloud sync beyond iCloud Photo Library
- In-app camera
- Video support (photos only for MVP)
- Multi-couple / group support

## Success Metrics
- Time to first "date" displayed < 3 seconds for libraries < 5,000 photos
- No crashes related to photo library access
- Positive sentiment on the emotional/romantic presentation

## Technical Constraints
- iOS 17+ only
- PhotoKit for all photo access (no direct file system access)
- Must support limited photo library access gracefully
- No external backend — fully on-device in MVP
- Privacy: no photos leave the device
