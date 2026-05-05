# WORPALOX

**WORPALOX** is an offline-first English-Russian word-order puzzle game built with Flutter for Android.

## Overview

Restore shuffled English sentences to their correct order using Russian translations as clues. Swap adjacent words to solve each puzzle. Designed for language learners who want a fun, bite-sized gameplay experience.

## Features

- **Offline-first**: All gameplay works without an internet connection
- **Local player profiles**: Multiple profiles on one device
- **Adaptive level selection**: Random levels from appropriate difficulty pool
- **Separate scoring**: Game score and learning progress tracked independently
- **Pre-learning stage**: Optional vocabulary preview with Skip button
- **Pedagogical result card**: Full sentence, translation, and learning commentary
- **Short levels**: 20 curated sentences (3-7 words each) for quick play sessions
- **Adjacent swap controls**: Tap swap buttons between neighboring words to reorder
- **Diff-style hints**: Visual feedback showing correct/incorrect word positions
- **Progress tracking**: Total solved, average swaps/checks, hint usage statistics

## Installation

### Prerequisites

- Flutter SDK 3.9.0 or later
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
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

## Corpus Data

The game uses a curated subset of aligned English-Russian sentence pairs:
- `assets/corpus/levels.json` - Playable dataset with difficulty, commentary, and pre-learning pairs

### Level Selection Criteria

For Release 2.0, levels are filtered to:
- 3-7 tokens (short, playable sentences)
- Literary prose content
- Each level includes:
  - `difficulty` (easy/medium/hard)
  - `commentaryRu` (pedagogical note in Russian)
  - `prelearnPairs` (2-3 curated vocabulary pairs)

## Gameplay Flow

1. **Home Screen**: Select/create profile, view stats, tap "Start Game" or "Continue"
2. **Pre-learning** (optional): Match English words to Russian equivalents, or tap Skip
3. **Puzzle Screen**: 
   - Russian sentence appears at top as clue
   - English sentence words are shuffled below
   - Tap swap buttons (↔) between adjacent words to reorder
   - Tap "Check" to verify solution
   - If incorrect, hints activate showing correct/incorrect positions
   - On success: score reveal, full sentence display, learning commentary
4. **Progress**: Stats auto-save to active profile after each completed level

## Controls

- **Swap**: Tap the ↔ button between two adjacent words
- **Check**: Verify current word order; activates hints if wrong
- **Show/Hide Hints**: Toggle visual hints manually (each show counts as hint use)
- **Reset**: Shuffle words and restart the puzzle

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
│   │   └── score_result.dart     # Score breakdown (game vs learning)
│   ├── services/
│   │   ├── corpus_service.dart   # Level loading & adaptive selection
│   │   ├── persistence_service.dart # JSON persistence (v2 schema, profiles)
│   │   ├── scoring_service.dart  # Separate game/learning score calculation
│   │   ├── hint_service.dart     # Diff-based hints
│   │   └── difficulty_service.dart # Difficulty pool selection
│   ├── screens/
│   │   ├── home_screen.dart      # Profile selection and stats
│   │   ├── prelearn_screen.dart  # Vocabulary preview with validation
│   │   └── puzzle_screen.dart    # Main puzzle gameplay
│   └── widgets/
│       ├── word_token.dart       # Word chip with hint coloring
│       ├── swap_button.dart      # Adjacent swap control
│       └── hint_overlay.dart     # Hint display helper
├── assets/corpus/
│   └── levels.json               # Playable dataset with metadata
├── test/
│   ├── unit/
│   │   ├── puzzle_state_test.dart
│   │   ├── scoring_service_test.dart
│   │   └── hint_service_test.dart
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
        "totalSwaps": 0,
        "totalChecks": 0,
        "totalHints": 0,
        "prelearnCorrect": 0,
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

Schema v1 saves are automatically migrated to v2 on first load.

## Scoring Formula

Transparent and motivating:

### Game Score
| Event | Points |
|-------|--------|
| Each swap | +1 |
| Each check | +2 |
| Solve bonus | +50 |
| First-check solve | +20 (bonus) |
| Each hint used | -5 |

### Learning Progress
| Event | Points |
|-------|--------|
| Base solve | +30 |
| First-check solve | +10 (bonus) |
| Pre-learning correct | +10 per answer |
| Repeated level | 30% gain (anti-grinding) |

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
flutter format lib/ test/
```

### Analyze code

```bash
flutter analyze
```

## License

Same license as the original corpus data. See `LICENSE` file.

## Acknowledgments

- Corpus data from Ruscorpora RNC EN-RU aligned corpus
- Original Python/Flet prototype provided gameplay concept reference
