---
title: Chess Performance & Training Platform — Product Requirements Document
last_modified: 2026-09-01
tags:
  - prd
  - phase1.2
  - planning
---

# Chess Performance & Training Platform — Product Requirements Document

**Status:** Draft
**Version:** 0.1
**Primary Data Source:** Lichess
**Analysis Engine:** Stockfish

---

## 1. Product Summary

The Chess Performance & Training Platform is a chess analytics and coaching application that analyzes a player's historical Lichess games to identify recurring strengths, weaknesses, and patterns in their play.

Rather than focusing primarily on individual-game engine accuracy, the application analyzes performance across many games to answer questions such as:

- What am I consistently doing well?
- What types of mistakes do I make repeatedly?
- Which areas of my game are improving?
- Which areas are getting worse?
- Are my mistakes concentrated in the opening, middlegame, or endgame?
- Do I struggle in particular openings or position types?
- Do I make poor decisions when low on time?
- Am I getting better at weaknesses I have been training?
- What should I work on next?

The application converts game and Stockfish analysis into measurable **chess themes**.

These themes are tracked across time and used to generate personalized training plans.

The core product loop is:

```text
Import Games
     ↓
Analyze Positions
     ↓
Identify Critical Events
     ↓
Classify Themes
     ↓
Measure Strengths & Weaknesses
     ↓
Create Training Plan
     ↓
Player Trains & Plays
     ↓
Import New Games
     ↓
Measure Improvement
```

The primary differentiator is therefore not engine analysis itself, but **longitudinal player development**.

---

## 2. Problem Statement

Chess players have access to excellent tools for analyzing individual games, including Lichess computer analysis and Stockfish.

These tools are good at answering:

> "Where did I make a mistake in this game?"

They are less effective at answering:

> "What mistakes do I repeatedly make across my games?"

and:

> "Am I actually getting better at those things?"

Players may review dozens or hundreds of games without recognizing recurring patterns such as:

- missing opponent threats;
- hanging pieces;
- playing critical positions too quickly;
- entering bad positions from a particular opening;
- failing to convert winning positions;
- repeatedly losing rook endgames;
- performing poorly against particular pawn structures;
- making tactical mistakes late in games.

The application will aggregate individual chess events into persistent themes that can be measured and trained.

---

## 3. Product Goals

## 3.1 Primary Goals

The application should allow a player to:

1. Import historical games from Lichess.
2. Analyze those games using Stockfish.
3. Measure overall chess performance.
4. Identify critical positions within games.
5. Classify mistakes and successful decisions into chess themes.
6. Identify recurring strengths and weaknesses.
7. Compare performance across different time periods.
8. Track improvement or regression within individual themes.
9. Create training plans targeting weaknesses.
10. Measure whether training results in improved game performance.

---

## 3.2 Long-Term Goal

The application should function as a **personal chess development system**.

Instead of merely telling a player what happened, it should progressively build a model of:

```text
What kind of chess player am I?

What am I good at?

What am I bad at?

What am I currently working on?

Is that training working?

What should I work on next?
```

---

## 4. Non-Goals

The MVP is not intended to:

- replace Lichess;
- provide live chess gameplay;
- compete with Stockfish as a chess engine;
- provide real-time assistance during games;
- automatically play moves;
- provide opening preparation for specific opponents;
- build a complete opening repertoire;
- accurately classify every possible chess concept;
- generate human-quality strategic explanations for every position.

The initial product should prioritize **reliable, measurable analysis over broad but unreliable coaching**.

---

## 5. Target User

The primary user is an amateur chess player who:

- plays regularly on Lichess;
- wants to improve;
- has enough games to identify recurring patterns;
- reviews games occasionally or regularly;
- understands basic chess terminology;
- wants more structured guidance than individual engine analysis provides.

The system should eventually support a broad rating range, but the MVP can initially target approximately:

**800–2000 Lichess rating.**

Recommendations should eventually adapt based on player strength.

---

## 6. Core Product Concepts

## 6.1 Game

A chess game imported from Lichess.

A game contains:

- Lichess game ID;
- player;
- opponent;
- player color;
- ratings;
- result;
- timestamp;
- time control;
- opening/ECO;
- PGN;
- clock information when available.

---

## 6.2 Position

A board state occurring before or after a move.

Positions provide the fundamental unit for Stockfish analysis.

A position may contain:

- FEN;
- move number;
- side to move;
- played move;
- best move;
- evaluation;
- clock;
- game phase;
- Stockfish principal variation.

---

## 6.3 Analysis Event

An important occurrence discovered while analyzing a game.

Examples include:

```text
Major evaluation loss
Missed tactical opportunity
Winning advantage lost
Drawn position lost
Critical move successfully found
Time-pressure mistake
Opening deterioration
```

Not every move needs to become an analysis event.

The system should focus on positions containing useful information about player performance.

---

## 6.4 Theme

A reusable chess concept associated with one or more analysis events.

Examples:

```text
Hanging Piece
Missed Opponent Threat
Fork
Pin
Back-Rank Weakness
King Safety
Time Trouble
Moving Too Quickly
Opening Knowledge
Rook Endgame
Passed Pawn
Poor Exchange
Lost Winning Position
```

Themes allow events across different games to be grouped together.

---

## 6.5 Theme Occurrence

An instance of a theme detected within a particular position.

Example:

```text
Game: abc123
Move: 27
Theme: Missed Opponent Threat
Severity: Major
Confidence: 0.94
```

One position may contain multiple theme occurrences.

---

## 6.6 Review Period

A collection of games analyzed together.

Examples:

```text
Last 30 games

August 2026

July 1 – July 31

Last 50 Blitz games
```

Review periods allow performance comparisons across time.

---

## 6.7 Training Goal

A specific theme selected for improvement.

Example:

```text
Theme:
Missed Opponent Threats

Baseline:
14.2 occurrences / 100 games

Target:
< 9 occurrences / 100 games
```

---

## 7. User Experience

## 7.1 Initial Setup

The user provides a Lichess username.

The application retrieves basic player information and available games.

The user chooses:

- date range;
- number of games;
- rated/unrated;
- time controls;
- optionally specific variants.

The MVP should support standard chess only.

---

## 8. Game Import

The application should retrieve games through the Lichess API.

Game import should support:

- username;
- start date;
- end date;
- maximum game count;
- time-control filtering;
- rated-game filtering.

Where available, imports should include:

- PGN;
- clock information;
- opening information;
- game metadata.

Imported games should be stored locally so that they do not need to be repeatedly retrieved from Lichess.

Duplicate imports must not create duplicate games.

The Lichess game ID should therefore act as an external unique identifier.

---

## 9. Stockfish Analysis

Stockfish provides the objective analytical foundation of the application.

For each relevant player move, the system should determine:

- evaluation before move;
- evaluation after move;
- best move;
- played move;
- centipawn loss;
- principal variation;
- mate evaluation where applicable.

---

## 9.1 Two-Pass Analysis

To reduce compute requirements, analysis should use two passes.

### Pass 1 — Position Scan

Perform relatively inexpensive analysis across all relevant positions.

Example target:

```text
Depth: approximately 12–16
```

The purpose is to identify potentially interesting positions.

### Pass 2 — Critical Position Analysis

Positions identified as significant receive deeper analysis.

Example target:

```text
Depth: approximately 18–24
MultiPV: approximately 3
```

Exact values should remain configurable.

---

## 10. Critical Position Detection

The application should identify positions where the player's decision had significant consequences.

Examples include:

- large evaluation change;
- only one move maintains the position;
- tactical opportunity;
- winning advantage gained;
- winning advantage lost;
- transition from winning to equal;
- transition from equal to losing;
- forced-mate sequence missed;
- severe mistake under time pressure.

Criticality should not depend exclusively on centipawn loss.

Candidate-move dispersion may also indicate criticality.

For example:

```text
Best move:       +1.2
Second choice:   +1.0
Third choice:    +0.8
```

is relatively forgiving.

Whereas:

```text
Best move:       +0.4
Second choice:   -2.1
Third choice:    -3.0
```

represents a highly critical decision.

---

## 11. Game Phase Classification

Every relevant position should be categorized as:

```text
Opening
Middlegame
Endgame
```

The initial implementation can use relatively simple rules based on:

- move count;
- opening database/ECO information;
- remaining material;
- queen presence;
- piece development.

More sophisticated phase classification may be introduced later.

---

## 12. Performance Metrics

The application should calculate metrics across individual games and review periods.

Initial metrics should include:

| Metric                     | Description                                 |
| -------------------------- | ------------------------------------------- |
| Win Rate                   | Percentage of games won                     |
| Draw Rate                  | Percentage drawn                            |
| Loss Rate                  | Percentage lost                             |
| ACPL                       | Average centipawn loss                      |
| Major Mistakes/Game        | Significant errors per game                 |
| Blunders/Game              | Severe errors per game                      |
| Critical Position Accuracy | Performance in important positions          |
| Opening Performance        | Position quality after opening              |
| Middlegame Performance     | Quality during middlegame                   |
| Endgame Performance        | Quality during endgame                      |
| Advantage Conversion       | Ability to convert winning positions        |
| Draw Preservation          | Ability to maintain drawable positions      |
| Recovery Rate              | Ability to recover from worse positions     |
| Time-Pressure Error Rate   | Mistakes while low on time                  |
| Fast-Move Error Rate       | Significant mistakes made unusually quickly |

Exact formulas should be explicitly defined and versioned.

---

## 13. Theme System

The theme system transforms engine events into understandable chess concepts.

Themes should belong to broader categories.

## 13.1 Initial Categories

### Tactics

Examples:

- Hanging Piece
- Fork
- Pin
- Skewer
- Discovered Attack
- Back-Rank Weakness
- Missed Mate
- Tactical Opportunity Missed

### Calculation

Examples:

- Missed Opponent Threat
- Incorrect Capture Sequence
- Premature Decision
- Candidate Move Failure

### Opening

Examples:

- Opening Knowledge
- Early Tactical Error
- Poor Development
- Early King Safety

### Strategy

Examples:

- Poor Piece Activity
- Weak Pawn Creation
- Poor Exchange
- King Safety
- Pawn Structure

### Endgame

Examples:

- King Activity
- Passed Pawn
- Rook Activity
- Pawn Endgame
- Conversion Technique

### Time Management

Examples:

- Time Trouble
- Moving Too Quickly
- Excessive Time Usage

### Conversion

Examples:

- Lost Winning Position
- Failed Advantage Conversion

### Defense

Examples:

- Failed Draw Preservation
- Missed Defensive Resource

---

## 14. Theme Classification

Theme classification should use multiple mechanisms.

## 14.1 Deterministic Rules

Use board state, move information, clock information, and engine evaluations.

These should be preferred whenever reliable.

Examples:

```text
Undefended piece captured
→ Hanging Piece

Player has very little clock time
→ Time Trouble

Player uses <2 seconds and loses 250cp
→ Moving Too Quickly
```

---

## 14.2 Engine-Based Classification

Stockfish candidate moves and principal variations can help determine tactical characteristics.

Examples include detecting:

- captures;
- checks;
- mating threats;
- tactical sequences;
- major material changes.

---

## 14.3 Model-Assisted Classification

A language model may eventually help classify difficult strategic concepts.

Potential inputs include:

- FEN;
- played move;
- best move;
- evaluation;
- candidate moves;
- principal variations;
- attack maps;
- game phase.

The language model must not replace Stockfish as the authoritative evaluator.

Model-generated classifications should be treated as lower-confidence unless independently verified.

---

## 15. Classification Confidence

Every theme occurrence should include a confidence score.

Example:

```text
Theme:
Hanging Piece

Confidence:
0.99

Classifier:
deterministic_rule
```

Another occurrence might be:

```text
Theme:
Poor Piece Activity

Confidence:
0.67

Classifier:
model
```

Possible classifier sources:

```text
rule
stockfish
model
manual
```

This allows the application to distinguish objective observations from subjective interpretation.

---

## 16. Evidence

Every identified strength or weakness should be explainable.

For example:

> Missed Opponent Threats occurred 11 times during this review period.

The user should be able to select that theme and view the positions responsible for the conclusion.

Each occurrence should show:

- board position;
- game;
- move number;
- played move;
- recommended move;
- evaluation change;
- explanation;
- severity;
- confidence.

This "show the evidence" capability is a core product requirement.

---

## 17. Strength Identification

The application should not exclusively analyze mistakes.

It should also identify repeated successful behavior.

Examples:

- successfully converting advantages;
- finding difficult moves;
- strong endgame play;
- good defensive resources;
- tactical opportunities found;
- good opening performance;
- accurate play in critical positions.

This allows reports to contain:

```text
Top Strengths
Top Weaknesses
```

rather than functioning purely as mistake reports.

---

## 18. Trend Analysis

Themes should be measured across review periods.

Example:

```text
Missed Opponent Threats
-----------------------

May       18.2 / 100 games
June      15.7
July       9.8
August     7.1

Trend: Strong Improvement
```

Possible trend classifications:

```text
Strong Improvement
Improving
Stable
Regressing
Strong Regression
Insufficient Data
```

Trend calculations should account for sample size.

---

## 19. Metric Normalization

Raw counts should generally not be used for cross-period comparisons.

For example:

```text
Period A: 100 games
Period B: 20 games
```

cannot meaningfully compare raw mistake counts.

Potential normalized metrics include:

```text
Occurrences / 100 games

Occurrences / 1,000 moves

Occurrences / 100 critical positions

Success percentage when theme is applicable
```

Different themes may require different denominators.

---

## 20. Review Report

Each review period should generate a report.

Example structure:

## Performance Summary

```text
Games: 43
Record: 21–4–18
Rating: +37

ACPL: 71
Blunders/Game: 0.81
Critical Position Accuracy: 63%
```

## Strongest Areas

```text
1. Advantage Conversion
2. Rook Endgames
3. Tactical Defense
```

## Primary Weaknesses

```text
1. Missed Opponent Threats
2. Moving Too Quickly
3. Back-Rank Tactics
```

## Trends

```text
Tactics            ↑ Improving
Opening            → Stable
Endgame            ↑ Improving
Time Management    ↓ Regressing
```

## Recommended Focus

```text
Primary:
Opponent Threat Recognition

Secondary:
Time Management
```

---

## 21. Training Plans

Users should be able to create a training plan from identified weaknesses.

A plan contains:

- start date;
- optional end date;
- targeted themes;
- baseline measurements;
- training activities;
- frequency;
- progress measurements.

Example:

```text
Primary Goal:
Improve opponent-threat recognition.

Baseline:
14.3 mistakes / 100 games

Target:
<9 mistakes / 100 games

Duration:
4 weeks
```

---

## 22. Training Activities

Potential training activities include:

- tactical puzzles;
- threat-identification exercises;
- endgame exercises;
- opening review;
- game review;
- calculation exercises;
- slower practice games;
- custom exercises generated from player games.

The MVP does not necessarily need to provide every training activity internally.

It may initially prescribe activities while tracking their completion.

---

## 23. Personalized Position Training

A particularly valuable feature is converting mistakes from the player's games into exercises.

For example:

```text
Game position at move 27
        ↓
Remove subsequent moves
        ↓
Present board to player
        ↓
"What should you play?"
```

The user attempts the position.

The application compares the response against Stockfish analysis.

This creates a personalized puzzle library based on actual weaknesses.

Positions can later be resurfaced using spaced repetition.

---

## 24. Training Effectiveness

The system should measure whether training corresponds with improved game performance.

Example:

```text
Theme:
Hanging Pieces

Before Training:
14.3 occurrences / 100 games

After Training:
8.1 occurrences / 100 games

Change:
-43%
```

Training progress should distinguish between:

**Exercise performance**

and:

**Real-game performance**

Solving tactical exercises successfully does not necessarily mean the player has eliminated the corresponding mistake during games.

Real-game improvement should therefore remain the primary success metric.

---

## 25. Dashboard

The primary dashboard should provide a high-level view of player development.

Possible sections:

### Current Performance

```text
Overall
Opening
Tactics
Middlegame
Endgame
Time Management
Conversion
```

### Current Strengths

Top recurring positive themes.

### Current Weaknesses

Top recurring negative themes.

### Trends

Performance changes across recent review periods.

### Active Training

Current goals and progress.

### Recent Analysis

Most recently imported games and review reports.

---

## 26. Theme Detail View

Selecting a theme should show:

```text
Theme Name
Description
Current Score
Trend
Occurrence Rate
Historical Chart
Training Status
```

followed by supporting positions.

Example:

```text
Missed Opponent Threats

Current:
7.1 / 100 games

Previous:
9.8 / 100 games

Improvement:
27.6%
```

The user should then be able to inspect every supporting game position.

---

## 27. Opening Analysis

Opening performance should initially be tracked by:

- ECO;
- opening name;
- color;
- evaluation leaving the opening;
- mistake frequency.

This could reveal patterns such as:

```text
White — Italian Game
Strong

White — Sicilian Defense
Weak

Black — Queen's Gambit
Stable

Black — King's Pawn openings
Improving
```

The MVP should avoid attempting to construct a complete opening repertoire.

---

## 28. Rating and Context Awareness

Player rating should influence interpretation.

A mistake significant for an advanced player may not be a useful training priority for a beginner.

Eventually analysis should account for:

- player rating;
- opponent rating;
- time control;
- game length;
- available clock time;
- position complexity.

Training recommendations should prioritize concepts appropriate to the player's level.

---

## 29. Proposed Domain Model

Initial entities:

```text
User

LichessAccount

Game

Position

EngineAnalysis

AnalysisEvent

Theme

ThemeOccurrence

ReviewPeriod

PerformanceMetric

TrainingPlan

TrainingGoal

Exercise

ExerciseAttempt
```

---

## 30. Example Relationships

```text
User
 ├── Games
 ├── ReviewPeriods
 └── TrainingPlans

Game
 └── Positions
      ├── EngineAnalysis
      └── AnalysisEvents
            └── ThemeOccurrences
                  └── Theme

ReviewPeriod
 ├── Games
 └── PerformanceMetrics

TrainingPlan
 └── TrainingGoals
       └── Theme

Exercise
 ├── SourcePosition
 └── ExerciseAttempts
```

---

## 31. Analysis Versioning

Analysis algorithms will change over time.

The system should therefore version:

- Stockfish configuration;
- metric definitions;
- critical-position algorithms;
- theme classifiers;
- theme taxonomy.

Example:

```text
analysis_version: 1
stockfish_version: 18
theme_classifier_version: 3
```

This prevents historical comparisons from silently changing when algorithms are updated.

Re-analysis can later explicitly migrate historical games to newer analysis versions.

---

## 32. Performance and Compute Considerations

Stockfish analysis will likely represent the largest computational workload.

Important considerations include:

- analysis depth;
- number of games;
- number of positions;
- MultiPV settings;
- concurrent engine processes;
- CPU availability;
- caching.

Engine results should be persisted.

The same position should not be unnecessarily reanalyzed using identical engine settings.

Analysis should run asynchronously so users do not need to keep a request open while hundreds of games are processed.

---

## 33. Lichess API Considerations

The application should:

- respect Lichess API rate limits;
- cache imported games;
- avoid repeatedly downloading unchanged games;
- support incremental synchronization;
- gracefully handle unavailable or incomplete game data.

A normal synchronization should eventually resemble:

```text
Find newest stored game
        ↓
Request games since that point
        ↓
Import new games
        ↓
Queue analysis
```

rather than repeatedly importing the player's entire history.

---

## 34. Privacy

Chess games are generally public, but user analysis and training information should be treated as user data.

Users should eventually be able to:

- disconnect their Lichess account;
- delete imported games;
- delete analysis history;
- delete training data;
- delete their application account.

---

## 35. MVP Scope

The MVP should prove the core hypothesis:

> Recurring chess weaknesses can be identified from historical games and measured over time.

## MVP Input

```text
Lichess username
Date range
Time-control filter
```

## MVP Game Analysis

Support:

- Stockfish evaluation;
- ACPL;
- mistakes;
- blunders;
- critical positions;
- opening/middlegame/endgame classification;
- clock analysis.

## MVP Themes

Begin with a deliberately small taxonomy such as:

1. Hanging Pieces
2. Missed Tactical Opportunities
3. Missed Opponent Threats
4. Poor Opening Performance
5. Time Trouble
6. Moving Too Quickly
7. Lost Winning Positions
8. Endgame Mistakes

These themes should be chosen because they can be detected with reasonably high confidence.

## MVP Reporting

Provide:

- overall performance;
- top strengths;
- top weaknesses;
- theme frequencies;
- supporting positions;
- comparison against previous review period.

## MVP Training

Allow the user to:

- select a weak theme;
- create a training goal;
- receive recommended training activities;
- track training completion;
- compare future game performance against the baseline.

---

## 36. Post-MVP Opportunities

Potential later features include:

### Personalized Puzzle Generation

Automatically generate exercises from player mistakes.

### Spaced Repetition

Resurface failed positions until consistently solved.

### Advanced Tactical Classification

Detect:

- forks;
- pins;
- skewers;
- discovered attacks;
- deflection;
- overloaded defenders;
- clearance;
- interference.

### Strategic Theme Classification

Detect concepts such as:

- weak squares;
- bad bishops;
- pawn weaknesses;
- poor piece activity;
- incorrect exchanges;
- positional sacrifices.

### Opening Repertoire Analysis

Track performance by opening and identify problematic variations.

### Opponent-Strength Adjustment

Adjust performance measurements based on opponent rating.

### Rating-Level Coaching

Modify recommendations based on player skill.

### Model-Assisted Coaching

Generate natural-language explanations from structured Stockfish analysis.

### Training Calendar

Create weekly training schedules from active goals.

### Coach/Student Accounts

Allow chess coaches to inspect player reports and assign training plans.

---

## 37. Product Principles

## Evidence Before Explanation

Every important diagnosis should link back to the positions that produced it.

## Trends Over Scores

The application should emphasize whether the player is improving rather than simply assigning a static rating.

## Real Games Over Artificial Performance

Training success should ultimately be measured through future games.

## Reliable Before Sophisticated

A reliable classification such as:

> "You hung an undefended piece."

is more valuable than an unreliable claim such as:

> "Your strategic understanding of isolated queen pawns is poor."

## Engine for Calculation, Models for Interpretation

Stockfish should determine chess evaluation.

Rules and other models may interpret those results.

## Training Must Close the Loop

Every major weakness should eventually lead to:

```text
Diagnosis → Training → Reassessment
```

---

## 38. Key Technical Challenges

The primary technical risks are not Lichess integration or Stockfish execution.

They are:

### Theme Classification

Determining _why_ a move was poor rather than simply determining that it was poor.

### Statistical Significance

Avoiding conclusions based on too few games or too few relevant positions.

### False Diagnoses

Preventing noisy engine analysis from becoming misleading coaching advice.

### Position Context

Understanding whether a mistake represents tactics, strategy, time management, opening knowledge, or some combination.

### Training Attribution

Determining whether improvement is actually associated with training rather than normal rating/game variance.

### Compute Cost

Analyzing hundreds or thousands of games deeply can become CPU-intensive.

---

## 39. MVP Success Criteria

The MVP should be considered successful if a user can:

1. Enter a Lichess username.
2. Import a defined period of games.
3. Have those games automatically analyzed.
4. Receive a meaningful performance summary.
5. See at least several recurring strengths and weaknesses.
6. Inspect the positions supporting those conclusions.
7. Compare those themes against another period.
8. Select a weakness as a training goal.
9. Follow a simple training plan.
10. Return after playing more games and determine whether the targeted weakness improved.

The ultimate test is whether the application can answer:

> **"What should I work on next, why, and is the work I've already done actually improving my chess?"**

If the system can answer those questions reliably, it provides meaningful value beyond ordinary engine analysis.
