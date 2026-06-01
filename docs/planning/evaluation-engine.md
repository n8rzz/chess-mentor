---
title: Evaluation Engine
last_modified: 2026-06-01
tags:
  - python
  - analysis
  - stockfish
  - planning
---

# Evaluation Engine

# 1. Overview

The Evaluation Engine is responsible for transforming imported chess games into structured analysis data that can be consumed by downstream systems.

The Evaluation Engine does not generate coaching advice, training plans, or progress reports.

Its responsibility is to produce objective analysis based on game data and engine evaluations.

The Evaluation Engine serves as the foundation for:

- Weakness Classification
- Training Plan Generation
- Progress Tracking
- Reporting
- Puzzle Extraction

---

# 2. Goals

## Primary Goals

- Parse imported PGN games
- Reconstruct all game positions
- Analyze user moves with Stockfish
- Calculate evaluation changes
- Identify candidate mistakes
- Generate structured analysis artifacts
- Produce deterministic and reproducible results

## Non-Goals

The Evaluation Engine will not:

- Explain mistakes
- Generate coaching recommendations
- Assign weakness themes
- Create training plans
- Render user interfaces

These responsibilities belong to downstream systems.

---

# 3. Inputs

## Game

Required:

- PGN
- User color
- Time control
- Game metadata

Optional:

- Clock information
- Opening information
- Provider metadata

---

# 4. Outputs

The Evaluation Engine produces:

## Position Analysis

For every user move:

- Position before move
- Position after move
- Best engine move
- Engine evaluation before move
- Engine evaluation after move
- Centipawn loss
- Classification

---

## Candidate Events

Potential coaching events.

Examples:

- Material loss
- Tactical opportunity
- Threat ignored
- Opening issue
- Time pressure event

These events are not weaknesses.

They are evidence consumed later by the classifier.

---

# 5. Architecture

Pipeline:

```text
PGN
 ↓
Game Parser
 ↓
Position Generator
 ↓
Engine Evaluator
 ↓
Event Detector
 ↓
Analysis Results
```

---

# 6. Game Parser

Responsibilities:

- Parse PGN
- Extract metadata
- Extract moves
- Validate game integrity

Output:

```text
Game
 └── Moves
```

Failures:

- Invalid PGN
- Incomplete game
- Unsupported format

Must return structured errors.

---

# 7. Position Generator

Responsibilities:

- Replay moves
- Generate board state before each move
- Generate board state after each move
- Produce FEN snapshots

Output:

For each move:

```text
MovePosition
- fen_before
- fen_after
```

---

# 8. Engine Evaluator

## Engine

Stockfish

## Default Depth

15

Future:

Configurable.

---

## Scope

Analyze:

- User moves only

Ignore:

- Opponent move analysis

---

## Evaluation Process

For each user move:

### Before Move

Analyze position.

Capture:

```text
best_move
principal_variation
evaluation_before
```

### After Move

Analyze resulting position.

Capture:

```text
evaluation_after
```

---

## Calculated Metrics

### Centipawn Loss

```text
evaluation_before
-
evaluation_after
```

---

### Evaluation Swing

Magnitude of change.

---

### Classification

Initial categories:

```text
Good
Inaccuracy
Mistake
Blunder
```

Thresholds configurable.

---

# 9. Event Detection

The Event Detector identifies objective signals.

It does not classify weaknesses.

Examples:

```text
Material Loss
Missed Tactical Opportunity
Threat Present
Threat Ignored
Mate Threat
Passed Pawn Created
King Exposure
Time Pressure
```

Output:

```text
CandidateEvent
```

---

# 10. Material Detector

Responsibilities:

Detect:

- Material won
- Material lost
- Exchange imbalances

Track:

```text
pawn
knight
bishop
rook
queen
```

Value calculations configurable.

---

# 11. Tactical Detector

Responsibilities:

Identify tactical opportunities.

Potential motifs:

```text
Fork
Pin
Skewer
Double Attack
Discovered Attack
Discovered Check
Back Rank Mate
Removal of Defender
Deflection
Decoy
Overloaded Piece
Zwischenzug
Mate Threat
```

Output:

```text
TacticalOpportunity
```

Contains:

- motif
- best line
- evaluation gain

---

# 12. Threat Detector

Responsibilities:

Identify:

- Material threats
- Tactical threats
- Mate threats

Output:

```text
Threat
```

Contains:

- threat_type
- severity
- target

---

# 13. King Safety Detector

Responsibilities:

Detect:

- Delayed castling
- Open king files
- Open king diagonals
- Pawn shield damage
- Mate threats

Output:

```text
KingSafetySignal
```

---

# 14. Pawn Structure Detector

Responsibilities:

Detect:

- Doubled pawns
- Isolated pawns
- Backward pawns
- Dangerous passed pawns

Output:

```text
PawnStructureSignal
```

---

# 15. Endgame Detector

Responsibilities:

Determine game phase.

Game phases:

```text
Opening
Middlegame
Endgame
```

Uses:

- Material
- Piece count
- Queen presence

Output:

```text
GamePhase
```

---

# 16. Time Pressure Detector

Responsibilities:

Use clock information when available.

Detect:

```text
TimePressureEvent
```

Default thresholds:

Bullet:

- <5 seconds

Blitz:

- <15 seconds

Rapid:

- <60 seconds

Classical:

- <180 seconds

Configurable.

---

# 17. Analysis Artifacts

The Evaluation Engine stores:

## Move Analysis

```text
move_number
fen_before
fen_after
best_move
played_move
evaluation_before
evaluation_after
centipawn_loss
classification
```

---

## Candidate Events

```text
event_type
severity
metadata
```

---

## Tactical Opportunities

```text
motif
best_line
evaluation_gain
```

---

## Threats

```text
type
severity
```

---

# 18. Error Handling

All failures must be structured.

Examples:

```text
Invalid PGN
Engine Failure
Position Reconstruction Failure
Unsupported Game
```

No unhandled exceptions should propagate.

---

# 19. Determinism

Identical inputs should produce identical outputs.

Store:

```text
engine_version
analysis_version
depth
```

with every analysis run.

Analysis results are immutable.

Historical results are not re-analyzed automatically.

---

# 20. Performance Goals

Target:

30 games

Average:

40-80 moves per game

Total:

1,200-2,400 user move evaluations

Acceptable runtime:

Under 10 minutes

Preferred runtime:

Under 5 minutes

Future optimization:

- Cached positions
- Parallel analysis
- Distributed workers

---

# 21. Testing Strategy

## Unit Tests

Game Parser

Position Generator

Material Detector

Threat Detector

Tactical Detector

King Safety Detector

Pawn Structure Detector

Endgame Detector

Time Pressure Detector

---

## Integration Tests

PGN → Evaluation

PGN → Events

PGN → Tactical Opportunities

---

## End-to-End Tests

PGN
↓
Analysis
↓
Artifacts

Validate deterministic outputs.

---

# 22. Success Criteria

Given a valid PGN:

The Evaluation Engine can:

1. Reconstruct positions.
2. Evaluate all user moves.
3. Calculate centipawn loss.
4. Detect objective candidate events.
5. Produce deterministic analysis artifacts.
6. Store analysis results for downstream consumers.

The Evaluation Engine is successful when downstream systems can generate coaching insights without requiring direct Stockfish access.
