# WORPALOX

**WORPALOX** is an offline-first English-Russian word-order puzzle game built with Flutter for Android.

## Overview

Restore shuffled English sentences to their correct order using Russian translations as clues. Drag any word to its place (or tap a word, then tap its place); the puzzle is solved automatically as soon as the order is right. Designed for language learners who want a fun, bite-sized gameplay experience.

## Features

- **Offline-first**: All gameplay works without an internet connection
- **Local player profiles**: Multiple profiles on one device
- **Adaptive level selection**: Random levels from appropriate difficulty pool
- **Separate scoring**: Game score and learning progress tracked independently
- **Two-step rounds**: "Step 1 · Learn Words" (multiple-choice warm-up, can be skipped) and "Step 2 · Puzzle"
- **Pedagogical result card**: Full sentence, translation, and learning commentary
- **Short levels**: 31 curated literary sentences (3-8 words each) for quick play sessions
- **Free word movement**: drag a word anywhere, or tap-to-select and tap-to-place
- **Automatic solve detection**: no "Check" button needed
- **Diff-style hints**: Visual feedback showing correct/incorrect word positions
- **Progress tracking**: Total solved, average moves, hint usage statistics

## Installation

### Prerequisites

- Flutter SDK 3.47 or later (Dart 3.13)
- Android Studio or VS Code with Flutter extensions

### Setup

```bash
flutter pub get
```

## Running the Game

### On Android device/emulator

```bash
flutter run
```

### Build APK for release

```bash
flutter build apk --release
flutter install --release      # phone connected via USB with USB debugging on
```

Without `android/key.properties` this build is signed with the debug key and
uses the application id `com.componavt.worpalox.dev` and the label
"WORPALOX dev", so it installs next to the Google Play version. Debug builds
(`flutter run`) use the same `.dev` id.

### Build for Google Play

Create `android/key.properties` (not tracked by git) pointing to your upload
keystore, then:

```bash
flutter build appbundle --release
```

The bundle will be at `build/app/outputs/bundle/release/app-release.aab`.
Only a bundle built with `key.properties` (application id
`com.componavt.worpalox`) can be uploaded to Google Play.

## Corpus Data

The game uses a curated subset of aligned English-Russian sentence pairs:
- `assets/corpus/levels.json` - Playable dataset with difficulty, commentary, and pre-learning pairs

### Level Selection Criteria

For Release 2.0, levels are filtered to:
- 3-9 tokens including punctuation (short, playable sentences)
- Literary prose content
- Each level includes:
  - `difficulty` (easy/medium/hard)
  - `commentaryRu` (pedagogical note in Russian)
  - `prelearnPairs` (2-3 curated vocabulary pairs)

## Gameplay Flow

1. **Home Screen**: tap "Play". On first launch the game asks for a player name.
2. **Step 1 · Learn Words** (optional): pick the English word for a Russian one, or tap "Skip to puzzle"
3. **Step 2 · Puzzle**:
   - Russian sentence appears at top as clue
   - English words are shuffled below; final punctuation stays fixed at the end
   - Move words until the order is right; the result appears immediately
   - On success: score breakdown, full sentence, translation, learning commentary
4. **Progress**: Stats auto-save to active profile after each completed level

## Controls

- **Drag**: drag a word onto another word to take its place (a bar shows where it will land)
- **Tap, tap**: tap a word to select it, then tap the word whose place it should take; tap it again to cancel
- **Hint**: colors words green (right place) or red (wrong place) until the next move; each hint costs 5 points
- **Shuffle**: mix the words again (move and hint counters are kept)

## Project Structure

```
worpalox-enru/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # MaterialApp with routes and providers
│   ├── models/
│   │   ├── level.dart            # Level data model with prelearnPairs
│   │   ├── puzzle_state.dart     # Runtime puzzle state
│   │   ├── stats.dart            # Per-profile statistics (v2 schema)
│   │   ├── player_profile.dart   # Local player profile model
│   │   ├── route_arguments.dart  # Learn Words -> Puzzle hand-over
│   │   └── score_result.dart     # Score breakdown (game vs learning)
│   ├── services/
│   │   ├── corpus_service.dart   # Level loading & adaptive selection
│   │   ├── persistence_service.dart # JSON persistence (v2 schema, profiles)
│   │   ├── scoring_service.dart  # Separate game/learning score calculation
│   │   └── difficulty_service.dart # Difficulty pool selection
│   ├── screens/
│   │   ├── home_screen.dart      # Profile selection and stats
│   │   ├── prelearn_screen.dart  # Vocabulary preview with validation
│   │   └── puzzle_screen.dart    # Main puzzle gameplay
│   └── widgets/
│       └── word_token.dart       # Word chip with hint/drag states
├── assets/corpus/
│   └── levels.json               # Playable dataset with metadata
├── test/
│   ├── unit/
│   │   ├── puzzle_state_test.dart
│   │   ├── scoring_service_test.dart
│   │   ├── services_test.dart    # corpus + persistence
│   │   └── ...
│   └── widget/
│       └── app_smoke_test.dart
├── pubspec.yaml
├── README.md
└── LICENSE
```

## Persistence Schema

Save data uses a versioned JSON schema stored via `shared_preferences`:

### Schema v2 (current)

```json
{
  "schemaVersion": 2,
  "activeProfileId": "default",
  "profiles": [
    {
      "id": "default",
      "name": "Player 1",
      "createdAt": "2024-01-01T00:00:00.000",
      "lastPlayedAt": "2024-01-01T00:00:00.000",
      "stats": {
        "totalGameScore": 0,
        "learningProgress": 0,
        "totalSolvedRuns": 0,
        "uniqueSolvedLevelIds": [],
        "recentLevelIds": [],
        "totalMoves": 0,
        "totalHints": 0,
        "prelearnCorrect": 0,
        "prelearnWrong": 0,
        "prelearnSkipped": 0,
        "problemWords": {},
        "difficultyPerformance": {
          "easy": 0,
          "medium": 0,
          "hard": 0
        }
      }
    }
  ]
}
```

Schema v1 saves are automatically migrated to v2 on first load. Older v2 saves
with `totalSwaps` are read as `totalMoves`. An unreadable save is copied to
`worpalox_save_v2_corrupt_backup` instead of being silently overwritten.

## Scoring Formula

Transparent and motivating:

### Game Score
| Event | Points |
|-------|--------|
| A word lands on its correct place for the first time | +2 |
| Solve bonus | +50 |
| Solved in the minimal number of moves | +20 |
| Solved within twice the minimal number of moves | +10 |
| Each hint used | -5 |

Extra moves never add points, so the shortest solution is always the best one.

### Learning Progress
| Event | Points |
|-------|--------|
| Base solve | +30 |
| Solved without hints | +10 |
| Pre-learning correct | +10 per answer |
| Repeated level | 30% of the total above (anti-grinding) |

Score is clamped to never go negative.

## Adaptive Level Selection

The game selects levels using this logic:

1. **Determine allowed difficulty pool** based on learning progress:
   - Beginner (0-2 solved): easy only
   - Early (progress < 100): easy + medium
   - Intermediate (progress < 300, medium < 5): easy + medium
   - Advanced: medium + hard
   - Expert: all difficulties

2. **Filter eligible levels**:
   - Must be in allowed difficulty pool
   - Prefer levels not in recent 20

3. **Random selection** from eligible pool

This prevents repetition while ensuring appropriate challenge.

## Development

### Run tests

```bash
flutter test
```

### Format code

```bash
dart format lib/ test/
```

### Analyze code

```bash
flutter analyze
```

## License

Code: MIT, see `LICENSE`. The sentences come from the RNC EN-RU aligned
corpus and remain subject to its terms.

## Acknowledgments

- Corpus data from Ruscorpora RNC EN-RU aligned corpus
- Original Python/Flet prototype provided gameplay concept reference
