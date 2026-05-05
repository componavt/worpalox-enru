# WORPALOX

**WORPALOX** is an offline-first English-Russian word-order puzzle game built with Flutter for Android.

## Overview

Restore shuffled English sentences to their correct order using Russian translations as clues. Swap adjacent words to solve each puzzle. Designed for language learners who want a fun, bite-sized gameplay experience.

## Features

- **Offline-first**: All gameplay works without an internet connection
- **Single short levels**: 36 curated sentences (4-8 words each) for quick play sessions
- **Adjacent swap controls**: Tap swap buttons between neighboring words to reorder
- **Russian clues**: Each puzzle shows the Russian translation as a hint
- **Diff-style hints**: Visual feedback showing correct/incorrect word positions
- **Progress tracking**: Total solved, average swaps/checks, hint usage statistics
- **Pre-learning mini-stage**: Lightweight vocabulary preview before each puzzle
- **Generous scoring**: Rewards meaningful interaction without punishing mistakes

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

The game uses a curated subset of aligned English-Russian sentence pairs from:
- `assets/corpus/enru.src` - English sentences (raw corpus, reference only)
- `assets/corpus/enru.tgt` - Russian sentences (raw corpus, reference only)
- `assets/corpus/enru.talp` - Word alignment data (for future smart hints)
- `assets/corpus/levels.json` - Derived playable dataset (36 short literary sentences)

### Level Selection Criteria

For Release 1.0, levels are filtered to:
- 4-8 tokens (short, playable sentences)
- Literary prose content (Dickens, Austen, Conan Doyle, etc.)
- Manually curated from the Ruscorpora RNC EN-RU aligned corpus

## Gameplay Flow

1. **Home Screen**: View stats, tap "Start Game"
2. **Pre-learning**: Match 2 English words to their Russian equivalents (minimal taps)
3. **Puzzle Screen**: 
   - Russian sentence appears at top as clue
   - English sentence words are shuffled below
   - Tap swap buttons (↔) between adjacent words to reorder
   - Tap "Check" to verify solution
   - If incorrect, hints activate showing correct/incorrect positions
   - On success: score reveal, triumph card, "Next Level" button
4. **Progress**: Stats auto-save after each completed level

## Controls

- **Swap**: Tap the ↔ button between two adjacent words
- **Check**: Verify current word order; activates hints if wrong
- **Show/Hide Hints**: Toggle visual hints manually
- **Reset**: Shuffle words and restart the puzzle

## Project Structure

```
worpalox-enru/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # MaterialApp with routes
│   ├── models/
│   │   ├── level.dart            # Level data model
│   │   ├── puzzle_state.dart     # Runtime puzzle state
│   │   └── stats.dart            # Aggregate statistics
│   ├── services/
│   │   ├── corpus_service.dart   # Level loading & selection
│   │   ├── persistence_service.dart # JSON persistence (v1 schema)
│   │   ├── scoring_service.dart  # Score calculation
│   │   ├── hint_service.dart     # Diff-based hints
│   │   ├── difficulty_service.dart # TODO stub
│   │   ├── audio_service.dart    # TODO stub
│   │   └── analytics_service.dart # TODO stub
│   ├── screens/
│   │   ├── home_screen.dart      # Start screen with stats
│   │   ├── prelearn_screen.dart  # Vocab preview mini-stage
│   │   └── puzzle_screen.dart    # Main puzzle gameplay
│   └── widgets/
│       ├── word_token.dart       # Word chip with hint coloring
│       ├── swap_button.dart      # Adjacent swap control
│       └── hint_overlay.dart     # Hint display helper
├── assets/corpus/
│   ├── levels.json               # Derived playable dataset
│   ├── enru.src                  # Raw English corpus
│   ├── enru.tgt                  # Raw Russian corpus
│   └── enru.talp                 # Raw alignment data
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

```json
{
  "schemaVersion": 1,
  "stats": {
    "totalSolved": 0,
    "totalSwaps": 0,
    "totalChecks": 0,
    "totalHints": 0,
    "levelsCompleted": [],
    "problemWords": {}
  },
  "lastPlayedLevelId": null
}
```

Future app versions can migrate by checking `schemaVersion`.

## Scoring Formula

Transparent and motivating:

| Event | Points |
|-------|--------|
| Each swap | +1 |
| Each check | +2 |
| Solve bonus | +50 |
| First-check solve | +20 (bonus) |
| Each hint used | -5 |

Score is clamped to [0, 9999] to never go negative.

## Future Features (Stubs Included)

The following services exist as clean stubs for future expansion:

- **Difficulty classifier**: Analyze sentence complexity, recommend levels
- **Audio service**: TTS for Russian clues and English sentences, SFX
- **Alignment-based hints**: Use `enru.talp` for smarter word-by-word mapping
- **Retry-mistakes mode**: Spaced review queue for problematic sentences
- **EN→RU mode**: Reverse direction gameplay
- **Analytics**: Event logging for A/B testing (privacy-focused, offline-first)

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
