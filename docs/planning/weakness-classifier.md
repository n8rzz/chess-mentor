---
title: Weakness Classifier
last_modified: 2026-06-01
tags:
  - python
  - weaknesses
  - classification
  - planning
---

# Weakness Classifier

# 1. Overview

The Weakness Classifier converts objective analysis artifacts produced by the Evaluation Engine into recurring weakness patterns.

The Weakness Classifier does not generate training plans or coaching recommendations.

Its responsibility is to:

- Interpret analysis results
- Classify weakness events
- Identify recurring patterns
- Measure weakness severity
- Track weakness lifecycle
- Detect improvement and regression

The output of the Weakness Classifier becomes the primary input for:

- Training Plan Generator
- Progress Tracker
- Dashboard Reporting

---

# 2. Goals

## Primary Goals

- Convert analysis artifacts into weakness events
- Identify recurring weaknesses
- Measure severity
- Track weakness progress
- Detect weakness improvement
- Detect weakness reappearance

## Non-Goals

The Weakness Classifier will not:

- Run Stockfish
- Generate training plans
- Explain weaknesses in natural language
- Assign puzzles
- Render UI

---

# 3. Inputs

Provided by Evaluation Engine.

## Move Analysis

Examples:

- Centipawn loss
- Best move
- Played move
- Classification

## Candidate Events

Examples:

- Material loss
- Tactical opportunity
- Threat ignored
- King exposure
- Pawn structure signal
- Time pressure signal

## Game Metadata

Examples:

- Rating
- Time control
- Opening
- Result

---

# 4. Outputs

## Weakness Events

Single occurrences.

Example:

```text
Move 18

Theme:
Hanging Pieces

Severity:
Major
```

---

## Weaknesses

Aggregated patterns.

Example:

```text
Hanging Pieces

Occurrences:
8

Frequency:
26%

Severity:
High

Status:
Active
```

---

## Weakness Cycles

Tracks recurrence over time.

Example:

```text
Hanging Pieces

Cycle #2

Status:
Active
```

---

# 5. Classification Pipeline

```text
Evaluation Artifacts
          ↓
Event Correlation
          ↓
Theme Classification
          ↓
Weakness Events
          ↓
Aggregation
          ↓
Weaknesses
          ↓
Cycle Tracking
```

---

# 6. Weakness Themes

## Tactical

### Hanging Pieces

### Missed Tactics

### Ignored Threats

---

## Opening

### Development Principles

### Opening Family Performance

Reporting only.

Not used for training plans in MVP.

---

## Positional

### King Safety

### Bad Trades

### Pawn Structure

---

## Endgame

### Endgame Technique

---

## Behavioral

### Time Pressure

---

# 7. Weakness Events

Weakness Events represent individual occurrences.

Example:

```text
Move 22

Theme:
Missed Tactics

Motif:
Fork

Severity:
Major
```

---

## Event Fields

Store:

- User
- Game
- Move
- Theme
- Primary Theme
- Secondary Theme
- Severity
- Metadata
- Timestamp

---

# 8. Hanging Pieces

## Classification Rule

Triggered when:

```text
User move creates
or leaves material
insufficiently defended
```

and

```text
Opponent can win material
```

---

## Punishment Types

### Actual Punishment

Opponent wins material.

### Missed Punishment

Opponent fails to exploit mistake.

Both count.

---

## Severity

Based on:

```text
Material at risk
+
Punishment modifier
```

Examples:

```text
Pawn
Minor Piece
Rook
Queen
```

---

# 9. Missed Tactics

## Classification Rule

Requires:

### Tactical Motif

Examples:

- Fork
- Pin
- Skewer
- Double Attack
- Discovered Attack
- Back Rank Mate
- Deflection
- Decoy
- Removal of Defender
- Overloaded Piece
- Zwischenzug

and

### Minimum Tactical Value

Default:

```text
1.5 pawns
```

or greater.

---

# 10. Ignored Threats

## Classification Rule

Triggered when:

```text
Opponent creates threat
```

and

```text
User fails to adequately address threat
```

and

```text
Position worsens significantly
```

---

## Valid Responses

Threat may be addressed by:

- Defense
- Retreat
- Counterattack
- Tactical sequence
- Greater threat
- Forced continuation

Ignoring a threat is not automatically a weakness.

---

# 11. Opening Development

## Development Signals

Examples:

- Early queen activity
- Repeated piece moves
- Delayed castling
- Undeveloped minor pieces
- Excessive pawn moves

---

## Opening Family Performance

Tracked separately.

Examples:

```text
Queen's Gambit
58%
```

```text
Italian Game
42%
```

Used for reporting only.

---

# 12. King Safety

## Signals

Examples:

- Delayed castling
- Open files near king
- Open diagonals near king
- Pawn shield damage
- Mate threats
- Defensive piece deficiencies

---

## Severity

Calculated using:

```text
King danger
+
Evaluation loss
+
Tactical consequences
```

---

# 13. Bad Trades

## MVP Scope

Materially losing trades only.

Triggered when:

```text
Trade occurs
```

and

```text
Evaluation worsens
```

and

```text
Material imbalance created
```

---

## Post-MVP

Expand to:

- Positional trades
- Endgame trades

---

# 14. Pawn Structure

## MVP Signals

Examples:

- Doubled pawns
- Isolated pawns
- Backward pawns
- Dangerous passed pawns

---

## Requirements

Structural weakness must:

```text
Worsen evaluation
```

to be counted.

---

# 15. Endgame Technique

## Endgame Detection

Based on:

- Material
- Piece count
- Queen presence

---

## MVP Signals

Examples:

- Missed promotion
- Stalemate
- Missed basic mate
- Failed conversion
- Opposition errors
- Pawn race errors

---

# 16. Time Pressure

## Role 1

Modifier.

Example:

```text
Hanging Pieces
+
Time Pressure
```

---

## Role 2

Standalone weakness.

Triggered when:

```text
Mistake rate under time pressure
significantly exceeds
normal mistake rate
```

---

## Default Thresholds

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

# 17. Weakness Detection

## Detection Window

Support both:

### Last N Games

Default:

```text
30 games
```

### Last N Days

Default:

```text
30 days
```

Configurable.

---

## Frequency Calculation

Weakness frequency:

```text
occurrences
/
games analyzed
```

Used instead of fixed occurrence counts.

---

# 18. Severity Model

Severity combines:

## Occurrence Score

Frequency of events.

---

## Impact Score

Damage caused.

Examples:

- Material loss
- Evaluation loss
- Mate threat

---

## Recency Score

Recent events weighted more heavily.

---

## Formula

Conceptually:

```text
Severity =
Occurrence
+
Impact
+
Recency
```

Implementation may evolve.

---

# 19. Weakness Lifecycle

## States

### Detected

Pattern exists.

Below activation threshold.

---

### Active

Official weakness.

---

### Improving

Reduction exceeds configurable threshold.

Default:

```text
30%
```

---

### Managed

Reduction exceeds target threshold.

Default:

```text
75%
```

---

### Archived

No longer actively tracked.

---

# 20. Weakness Cycles

Weaknesses may reappear.

Example:

```text
Hanging Pieces

Cycle #1
Managed
```

Later:

```text
Hanging Pieces

Cycle #2
Active
```

A new cycle is created.

Previous cycles remain historical.

---

# 21. Progress Measurement

Track:

- Frequency
- Severity
- Status
- Cycle Count
- Duration
- Improvement %

---

## Example

```text
Hanging Pieces

Cycle #2

Baseline:
12

Current:
4

Reduction:
67%

Status:
Improving
```

---

# 22. Determinism

Given identical analysis artifacts:

The classifier must produce identical weakness outputs.

No LLM involvement in classification.

Rule-based classification only.

---

# 23. Testing Strategy

## Unit Tests

Per theme:

- Hanging Pieces
- Missed Tactics
- Ignored Threats
- Opening Development
- King Safety
- Bad Trades
- Pawn Structure
- Endgame Technique
- Time Pressure

---

## Integration Tests

Evaluation Artifacts
→ Weakness Events

Weakness Events
→ Weaknesses

Weaknesses
→ Cycles

---

## End-to-End Tests

PGN
→ Evaluation Engine
→ Weakness Classifier
→ Weakness Output

Validate deterministic behavior.

---

# 24. Success Criteria

Given evaluated games:

The Weakness Classifier can:

1. Detect weakness events.
2. Aggregate recurring patterns.
3. Rank weaknesses by severity.
4. Track lifecycle progression.
5. Measure improvement.
6. Detect recurrence.
7. Produce deterministic outputs.

The Weakness Classifier is successful when it consistently identifies meaningful recurring weaknesses that users recognize as accurate descriptions of their play.
