---
title: Training Plan Generator
last_modified: 2026-06-01
tags:
  - python
  - training
  - planning
---

# Training Plan Generator

# 1. Overview

The Training Plan Generator converts detected weaknesses into structured improvement plans.

The purpose of the Training Plan Generator is to help users reduce recurring weaknesses through focused practice and measurable improvement.

The Training Plan Generator consumes outputs from the Weakness Classifier and produces actionable assignments.

The Training Plan Generator does not:

- Run Stockfish
- Analyze games
- Detect weaknesses
- Render user interfaces

Those responsibilities belong to other systems.

---

# 2. Goals

## Primary Goals

- Generate personalized training plans
- Target one weakness at a time
- Assign relevant exercises
- Measure improvement
- Adapt to user progress
- Create repeatable coaching workflows

## Non-Goals

### MVP

- AI coaching chat
- Dynamic daily lesson generation
- Human coach interaction
- Multiple simultaneous plans
- Adaptive scheduling

---

# 3. Inputs

Provided by Weakness Classifier.

## Weakness

Examples:

```text
Hanging Pieces

Missed Tactics

King Safety

Pawn Structure
```

---

## Weakness Cycle

Contains:

- Baseline frequency
- Baseline severity
- Detection window
- Status

---

## Weakness Events

Examples:

```text
Move 22

Missed Fork
```

```text
Move 18

Hung Bishop
```

---

## User Profile

Examples:

- Current rating
- Time control preference
- Training history

---

# 4. Outputs

## Training Plan

A structured improvement program.

---

## Training Assignments

Examples:

```text
Puzzle

Position Review

Play Game

Habit Exercise
```

---

## Progress Targets

Examples:

```text
Reduce frequency by 30%

Reduce frequency by 75%
```

---

# 5. Core Philosophy

A training plan should:

```text
Identify
↓
Practice
↓
Apply
↓
Measure
```

The objective is not puzzle completion.

The objective is reduction of weakness frequency.

---

# 6. Active Plans

## MVP

One active plan per user.

A user may:

- Start
- Pause
- Resume
- Complete
- Archive

a plan.

---

## Future

Multiple concurrent plans.

Subscription feature.

---

# 7. Training Plan Lifecycle

## Recommended

System recommends plan.

---

## Active

User accepts plan.

---

## Improving

Weakness reduction exceeds threshold.

Default:

30%

---

## Managed

Weakness reduction exceeds target.

Default:

75%

---

## Completed

Plan finished successfully.

---

## Archived

No longer active.

---

# 8. Plan Selection

## Recommendation Process

Classifier produces ranked weaknesses.

Example:

```text
Hanging Pieces
Severity 82

King Safety
Severity 71

Missed Tactics
Severity 65
```

System recommends:

Top 3 weaknesses.

User chooses one.

---

# 9. Plan Duration

Default:

14 days

Configurable.

---

## Extension

Users may continue plan.

Example:

```text
14 days complete

Improvement:
20%

Target:
75%
```

Plan remains active.

---

# 10. Plan Structure

Every plan contains:

## Personal Position Review

## Theme Puzzles

## Play Assignments

## Habit Training

---

# 11. Personal Position Reviews

Source:

User's own games.

Examples:

```text
Move 18

Hung Bishop
```

```text
Move 22

Missed Fork
```

Purpose:

Reconnect user with actual mistakes.

---

## Daily Target

Default:

1 position review

---

# 12. Theme Puzzles

Source:

Curated puzzle database.

Mapped to weakness theme.

Examples:

```text
Forks

Pins

Skewers
```

for Missed Tactics.

---

## Daily Target

Default:

5 puzzles

---

## Puzzle Difficulty

Based on:

- User rating
- Historical performance

---

# 13. Play Assignments

Purpose:

Apply learning in real games.

---

## Daily Target

Default:

1 game

Preferred:

Rapid

Secondary:

Blitz

Bullet discouraged for training.

---

# 14. Habit Exercises

Behavioral reminders.

Examples:

## Hanging Pieces

Before every move ask:

```text
What is attacked?
```

---

## Missed Tactics

Before every move ask:

```text
Do I have a forcing move?
```

---

## King Safety

Before every move ask:

```text
Is my king safe?
```

---

Purpose:

Create repeatable thinking patterns.

---

# 15. Theme-Specific Plans

## Hanging Pieces

Focus:

- Board awareness
- Piece safety
- Threat recognition

Assignments:

- Personal blunder review
- Hanging-piece puzzles
- Threat scanning habit

---

## Missed Tactics

Focus:

- Tactical pattern recognition

Assignments:

- Fork puzzles
- Pin puzzles
- Tactical reviews

---

## Ignored Threats

Focus:

- Opponent plans

Assignments:

- Defensive puzzles
- Threat identification exercises

---

## King Safety

Focus:

- Castling
- Pawn shield
- Mate awareness

Assignments:

- Mating attack reviews
- Defensive puzzles

---

## Bad Trades

Focus:

- Material evaluation

Assignments:

- Exchange exercises
- Trade evaluation reviews

---

## Pawn Structure

Focus:

- Structural awareness

Assignments:

- Structure reviews
- Pawn-endgame exercises

---

## Endgame Technique

Focus:

- Conversion
- Promotion
- Opposition

Assignments:

- Endgame puzzles
- Conversion drills

---

## Time Pressure

Focus:

- Decision efficiency

Assignments:

- Timed puzzles
- Slower games
- Move checklist habits

---

# 16. Progress Measurement

## Baseline

Captured when plan begins.

Example:

```text
Hanging Pieces

Occurrences:
12
```

---

## Current

Updated after analysis.

Example:

```text
Occurrences:
7
```

---

## Reduction

```text
(12 - 7) / 12
```

---

## Status

Detected

Active

Improving

Managed

Archived

---

# 17. Success Criteria

## Improving

Default:

30% reduction

Configurable.

---

## Managed

Default:

75% reduction

Configurable.

---

## Completion

Plan completes when:

Managed threshold reached.

or

User manually completes.

---

# 18. Failure Criteria

Plan may fail when:

```text
No improvement
```

after configurable period.

Example:

```text
14 days

0% reduction
```

---

## System Response

Recommend:

New plan

or

Extended plan

---

# 19. Weakness Reappearance

If weakness returns:

Create new Weakness Cycle.

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

New plan may be generated.

---

# 20. Progress Reporting

Track:

- Weakness frequency
- Severity
- Reduction %
- Puzzle completion
- Position review completion
- Games played

---

## Dashboard Examples

### Active Plan

```text
Theme:
Hanging Pieces

Progress:
42%

Status:
Improving
```

---

### Trend

```text
Occurrences

12
↓
10
↓
7
↓
5
```

---

# 21. Determinism

Given identical inputs:

The generator should create identical plans.

No LLM required for plan generation.

Rule-based plan generation in MVP.

---

# 22. Future Enhancements

## AI Explanations

Generate personalized coaching narratives.

---

## Adaptive Plans

Adjust assignments based on performance.

---

## Multiple Plans

Run multiple weaknesses simultaneously.

---

## Coach Marketplace

Human coach review.

---

## User-Created Plans

Custom training goals.

---

# 23. Testing Strategy

## Unit Tests

Plan selection

Plan generation

Progress calculation

Status transitions

---

## Integration Tests

Weakness
↓
Training Plan

Training Plan
↓
Progress Updates

---

## End-to-End Tests

PGN
↓
Evaluation Engine
↓
Weakness Classifier
↓
Training Plan Generator
↓
Progress Tracking

Validate deterministic outcomes.

---

# 24. Success Criteria

Given a classified weakness:

The Training Plan Generator can:

1. Create a personalized plan.
2. Assign relevant exercises.
3. Measure progress.
4. Detect improvement.
5. Complete or extend plans appropriately.

The Training Plan Generator is successful when users demonstrate measurable reduction in targeted weaknesses and sustained improvement over time.
