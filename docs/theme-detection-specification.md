---
title: Theme Detection Specification
last_modified: 2026-09-01
tags:
  - tasks
  - checklist
  - planning
---

# Theme Detection Specification

> **Implementation note (2026-09-08):** Shipped via `weakness_package` taxonomy `1.1.0` as eleven `Patternable` patterns (Phase 1.2 eight plus king safety, bad trades, pawn structure). Multi-label occurrences with confidence + evidence. See [weakness-classifier-engine.md](weakness-classifier-engine.md).

## 1. Purpose

This document defines how the MVP identifies recurring chess themes from analyzed games.

The goal is not to perfectly explain every chess mistake. The MVP should instead detect a small number of useful themes with reasonably high confidence and enough supporting evidence that a player can inspect and understand each diagnosis.

The initial theme engine supports eight negative-performance themes:

1. Hanging Pieces
2. Missed Tactical Opportunities
3. Missed Opponent Threats
4. Poor Opening Performance
5. Time Trouble
6. Moving Too Quickly
7. Lost Winning Positions
8. Endgame Mistakes

Each detected occurrence should answer four questions:

```text
What happened?

How serious was it?

How confident are we in the classification?

What evidence supports it?
```

---

## 2. Design Principles

### 2.1 Prefer Precision Over Recall

The MVP should prefer missing an ambiguous occurrence rather than incorrectly labeling it.

For example, if the system is uncertain whether a move represents a tactical oversight or a strategic mistake, it should avoid forcing the position into a tactical category.

---

### 2.2 Multiple Themes May Apply

A position may produce multiple theme occurrences.

Example:

```text
Player has 8 seconds remaining.

Player immediately plays a move in 0.7 seconds.

The move hangs a rook and changes the evaluation
from +0.3 to -5.8.
```

The position may reasonably receive:

```text
Hanging Piece
Time Trouble
Moving Too Quickly
Missed Opponent Threat
```

Each occurrence should be stored independently.

---

### 2.3 Stockfish Determines Evaluation

Stockfish determines:

- whether a move was good or bad;
- evaluation changes;
- best moves;
- candidate moves;
- tactical continuations.

Theme rules interpret that information.

Theme classifiers must not override Stockfish evaluation.

---

### 2.4 Every Occurrence Must Be Explainable

A detected theme must contain enough data to show why it was triggered.

The user should eventually be able to inspect the relevant position and see:

```text
Played move
Best move
Evaluation before
Evaluation after
Evaluation loss
Relevant tactical sequence
Clock information
Detection reason
Confidence
```

---

## 3. Required Analysis Inputs

For every player move considered by the Theme Engine, the application should provide a normalized analysis object.

Suggested structure:

```json
{
  "game_id": "abc123",
  "ply": 47,
  "move_number": 24,
  "color": "white",

  "fen_before": "...",
  "fen_after": "...",

  "played_move": "Qxd5",
  "best_move": "Rxf7",

  "eval_before_cp": 45,
  "eval_after_cp": -218,

  "mate_before": null,
  "mate_after": null,

  "centipawn_loss": 263,

  "best_line": [],
  "candidate_lines": [],

  "clock_before_ms": 84000,
  "clock_after_ms": 82100,
  "move_time_ms": 1900,

  "game_phase": "middlegame",

  "material_before": {},
  "material_after": {},

  "attack_map_before": {},
  "attack_map_after": {}
}
```

All evaluations should be normalized from the analyzed player's perspective.

Therefore:

```text
positive evaluation = good for player
negative evaluation = bad for player
```

regardless of whether the player is White or Black.

---

## 4. Shared Evaluation Thresholds

The MVP should define a central configuration object rather than hardcode numbers throughout individual classifiers.

Initial suggested thresholds:

| Name                   |       Default |
| ---------------------- | ------------: |
| Minor error            |         50 cp |
| Significant error      |        100 cp |
| Major error            |        200 cp |
| Severe blunder         |        400 cp |
| Clearly winning        |       +200 cp |
| Strongly winning       |       +400 cp |
| Clearly losing         |       -200 cp |
| Approximately equal    | -75 to +75 cp |
| Critical candidate gap |        150 cp |

These numbers should be configurable and versioned.

Example:

```yaml
evaluation:
  minor_error_cp: 50
  significant_error_cp: 100
  major_error_cp: 200
  severe_blunder_cp: 400

  winning_cp: 200
  strongly_winning_cp: 400
  losing_cp: -200

  equal_band_cp: 75

  critical_candidate_gap_cp: 150
```

---

## 5. Severity

All negative theme occurrences should use a shared severity vocabulary.

```text
minor
moderate
major
severe
```

Suggested mapping from evaluation loss:

| Evaluation Loss | Severity |
| --------------- | -------- |
| 50–99 cp        | Minor    |
| 100–199 cp      | Moderate |
| 200–399 cp      | Major    |
| 400+ cp         | Severe   |

Special events can override this.

For example:

```text
missed forced mate
```

should generally be at least `major` even when centipawn representation is unavailable.

---

## 6. Confidence

Confidence describes how certain the system is that the assigned theme accurately explains the position.

Use:

```text
0.00 – 1.00
```

Recommended interpretation:

| Confidence | Meaning                                    |
| ---------- | ------------------------------------------ |
| 0.90–1.00  | Very high confidence                       |
| 0.75–0.89  | High confidence                            |
| 0.60–0.74  | Moderate confidence                        |
| <0.60      | Do not normally expose as an MVP diagnosis |

The MVP should generally require:

```text
confidence >= 0.65
```

before displaying a theme occurrence to the user.

Lower-confidence occurrences may still be retained internally for classifier testing.

---

## 7. ThemeOccurrence Schema

Suggested model:

```text
ThemeOccurrence
------------------------------
id
game_id
position_id
theme_id

severity
confidence

evaluation_before
evaluation_after
evaluation_loss

classifier
classifier_version

detection_reason
evidence

created_at
```

`evidence` can initially be structured JSON.

Example:

```json
{
  "piece": "white_rook",
  "square": "d1",
  "attacker": "black_bishop",
  "played_move": "a3",
  "best_move": "Rxd8",
  "material_loss": 5
}
```

---

## 8. Theme 1 — Hanging Piece

### Definition

The player leaves a materially valuable piece vulnerable to capture without sufficient tactical compensation.

This includes both:

```text
placing a piece en prise
```

and:

```text
failing to respond to an already attacked piece
```

---

### Primary Trigger

Detect when all of the following are true:

```text
1. Played move causes or preserves an unfavorable attack
   against one of the player's non-pawn pieces.

2. The opponent can capture that piece immediately
   or within a short forced sequence.

3. Material loss is meaningful.

4. Stockfish evaluation deteriorates by at least
   significant_error_cp.
```

Initial meaningful material threshold:

```text
>= 3 pawn-equivalent points
```

Typical values:

```text
Pawn   = 1
Knight = 3
Bishop = 3
Rook   = 5
Queen  = 9
```

---

### Strong Detection Example

Before:

```text
White rook on c1 is attacked.
```

Player plays:

```text
h3??
```

Opponent can play:

```text
...Rxc1
```

and win the rook.

Evaluation:

```text
Before: +0.1
After:  -4.8
```

Result:

```text
Theme: Hanging Piece
Severity: Severe
Confidence: ~0.98
```

---

### Confidence Calculation

Base:

```text
0.75
```

Add:

```text
+0.10 if loss is immediate
+0.10 if material loss >= rook
+0.05 if Stockfish PV begins with the capture
```

Subtract:

```text
-0.15 if tactical compensation exists
-0.10 if capture requires >2 ply
-0.10 if resulting material evaluation is unclear
```

Cap:

```text
0.99
```

---

### Exclusions

Do not classify as Hanging Piece when:

- the piece is intentionally sacrificed with sufficient compensation;
- the best line recovers material;
- the move leads to forced mate for the player;
- evaluation remains approximately unchanged;
- material loss is part of an equal exchange.

---

## 9. Theme 2 — Missed Tactical Opportunity

### Definition

The player had a concrete tactical sequence producing a substantial advantage but failed to play it.

This is deliberately broader than fork, pin, skewer, etc. for the MVP.

Those tactical motifs can become subthemes later.

---

### Primary Trigger

Detect when:

```text
1. Stockfish's best move creates a large advantage.

2. The played move fails to obtain that advantage.

3. The best line contains a forcing tactical sequence.

4. Candidate move difference exceeds a configured threshold.
```

Suggested requirements:

```text
best move advantage >= +150 cp

AND

played move is >= 150 cp worse than best move
```

At least one of the first several moves in the principal variation should contain:

```text
check
capture
promotion
forced material win
mate threat
```

---

### Example

Position evaluation:

```text
Best move: Nxf7!
Evaluation: +3.4

Played move: a3
Evaluation: +0.3
```

Stockfish continuation:

```text
Nxf7 Kxf7
Qh5+
```

Result:

```text
Theme: Missed Tactical Opportunity
Severity: Major
Confidence: 0.91
```

---

### Forced Mate

If Stockfish identifies a forced mating sequence that the player misses:

```text
Theme:
Missed Tactical Opportunity

Subtype:
Missed Mate
```

Severity should normally be:

```text
severe
```

unless the player retains another overwhelming advantage.

---

### Confidence

Base:

```text
0.70
```

Add:

```text
+0.10 forcing move is check
+0.10 clear material gain
+0.10 forced mate
+0.05 candidate gap >300 cp
```

Subtract:

```text
-0.10 tactical sequence >5 ply
-0.10 position contains multiple similarly strong moves
```

---

## 10. Theme 3 — Missed Opponent Threat

### Definition

The opponent created a concrete threat and the player failed to respond appropriately.

This differs from Hanging Piece because the threat may involve:

- checkmate;
- material loss;
- tactical combination;
- promotion;
- attack against the king.

---

### Detection Strategy

Analyze the position before the player's move.

Determine whether the opponent has a strong tactical continuation if the player does nothing useful.

One practical method is comparing Stockfish candidates.

If defensive moves dominate the best candidate list and the played move ignores the threat, classify the event.

---

### Primary Trigger

Suggested conditions:

```text
1. Position before move contains a concrete opponent threat.

2. Stockfish recommends a defensive or threat-neutralizing move.

3. Played move does not address the threat.

4. Evaluation falls by >= 150 cp.
```

Possible threat indicators:

```text
opponent mate threat
attacked high-value piece
promotion threat
fork threat
discovered attack
forced material sequence
king attack
```

---

### Example

Opponent threatens:

```text
...Qh2#
```

Player plays:

```text
Rc1??
```

instead of:

```text
g3
```

Result:

```text
Theme: Missed Opponent Threat
Severity: Severe
Confidence: 0.98
```

---

### Confidence

Base:

```text
0.65
```

Add:

```text
+0.20 forced mate threat
+0.15 immediate material loss
+0.10 best moves all address same threat
+0.05 opponent continuation is forcing
```

Subtract:

```text
-0.15 threat requires >4 ply
-0.10 multiple unrelated defensive ideas exist
```

---

### Relationship to Hanging Piece

Both may apply.

Example:

```text
Opponent attacks rook.
Player ignores attack.
Opponent captures rook.
```

Detect:

```text
Missed Opponent Threat
Hanging Piece
```

This is desirable.

The first describes the decision failure.

The second describes the tactical consequence.

---

## 11. Theme 4 — Poor Opening Performance

### Definition

The player repeatedly leaves the opening in a significantly worse position.

The MVP should avoid claiming the player "doesn't know the opening" unless sufficient repeated evidence exists.

Individual occurrences should therefore represent:

```text
Poor Opening Outcome
```

while aggregated review-period analysis can produce:

```text
Poor Opening Performance
```

---

## 12. Opening Boundary

Initially define the opening as:

```text
moves 1–12
```

with the option to extend to:

```text
move 15
```

when the position still matches known opening theory.

A more sophisticated opening-boundary system can be introduced later.

---

### Per-Game Trigger

At opening exit:

```text
player evaluation <= -100 cp
```

and at least one opening move caused:

```text
>= 75 cp evaluation loss
```

Store:

```text
ECO
opening name
color
opening exit evaluation
largest opening mistake
```

---

### Aggregated Theme Trigger

Do not classify an opening as a weakness from one game.

Suggested minimum:

```text
>= 5 games in same opening family
```

Possible classification:

```text
average opening exit evaluation <= -75 cp

OR

>= 40% of games leave opening at <= -100 cp
```

---

### Example

```text
Opening:
Sicilian Defense

Color:
White

Games:
12

Average exit evaluation:
-1.1

Games worse than -1.0:
7 / 12
```

Result:

```text
Theme:
Poor Opening Performance

Confidence:
High
```

---

### Confidence

Primarily sample-size based.

Example:

```text
3 games  → insufficient evidence
5 games  → moderate
10 games → high
20 games → very high
```

Performance consistency should also affect confidence.

---

## 13. Theme 5 — Time Trouble

### Definition

A significant mistake occurs when the player has very little remaining clock time.

This theme describes context rather than necessarily the chess cause.

---

## 14. Time-Trouble Threshold

Time trouble must account for time control.

A simple MVP calculation can use:

```text
remaining_time_ratio =
remaining_clock /
initial_clock
```

Trigger time trouble if either:

```text
remaining clock <= 10 seconds
```

or:

```text
remaining_time_ratio <= 5%
```

For longer games, use an additional threshold such as:

```text
remaining clock <= 30 seconds
```

when the initial time is at least 10 minutes.

These values should remain configurable.

---

### Occurrence Trigger

```text
1. Player is in time trouble.

2. Player makes a mistake >= 100 cp.
```

---

### Example

```text
Time control:
5+3

Clock:
00:07

Move:
Qd4??

Evaluation:
+0.2 → -2.4
```

Result:

```text
Theme:
Time Trouble

Severity:
Major

Confidence:
0.95
```

The high confidence refers to the factual relationship between the mistake and clock state, not the claim that time pressure definitively caused the mistake.

---

## 15. Theme 6 — Moving Too Quickly

### Definition

The player makes a significant mistake despite having enough clock time available and spends unusually little time considering the move.

This theme attempts to detect preventable impulsive decisions.

---

## 16. Move-Time Calculation

Where Lichess clock data is available:

```text
move_time =
previous_clock
+ increment
- resulting_clock
```

Account for network or clock rounding noise.

Negative or impossible values should be discarded.

---

### Primary Trigger

Suggested MVP rule:

```text
move_time <= 2 seconds

AND

remaining_clock >= 30 seconds

AND

evaluation_loss >= 150 cp
```

For long time controls, consider:

```text
move_time <= 3 seconds
```

---

### Stronger Trigger

Confidence increases significantly when the position is critical.

Example:

```text
best move:      +0.5
second move:    -2.0
played move:    -2.4
```

and the player uses:

```text
1.1 seconds
```

despite having:

```text
4:30
```

remaining.

---

### Confidence

Base:

```text
0.70
```

Add:

```text
+0.10 move <1 sec
+0.10 evaluation loss >300 cp
+0.10 critical candidate gap >150 cp
+0.05 remaining time >50% of initial clock
```

Subtract:

```text
-0.15 obvious forced move
-0.15 move occurs in known opening theory
-0.10 position contains only one legal or reasonable move
```

---

### Important Exclusion

Do not classify fast moves during the early opening if the move remains consistent with known opening theory.

Fast theoretical moves are expected.

---

## 17. Theme 7 — Lost Winning Position

### Definition

The player obtains a clearly winning position but subsequently gives away most or all of the advantage.

This theme is extremely useful because it measures conversion rather than isolated move accuracy.

---

## 18. Winning State

Initial definition:

```text
evaluation >= +200 cp
```

for at least:

```text
2 consecutive player decision points
```

This avoids treating a temporary engine spike as an established winning position.

A stronger winning state:

```text
evaluation >= +400 cp
```

---

### Loss-of-Advantage Trigger

After entering a winning state, detect when the evaluation subsequently becomes:

```text
< +75 cp
```

This means the game has returned to approximately equal.

More severe cases:

```text
winning → losing
```

where evaluation drops below:

```text
-100 cp
```

---

### Example

```text
Move 27:
+4.8

Move 28:
+4.2

Move 31:
+3.9

Move 34:
+0.2
```

Result:

```text
Theme:
Lost Winning Position
```

The system should identify the move or sequence responsible for the largest deterioration.

---

### Severity

Suggested:

```text
Winning → still better:
moderate

Winning → equal:
major

Winning → losing:
severe

Forced mate → no longer winning:
severe
```

---

### Game-Level Conversion Metric

Track:

```text
winning_positions_reached

winning_positions_converted

conversion_rate
```

Example:

```text
Winning positions reached: 14
Converted: 9

Conversion rate: 64.3%
```

This should become one of the primary longitudinal metrics.

---

## 19. Theme 8 — Endgame Mistake

### Definition

A significant mistake occurring after the game has entered an endgame state.

The MVP uses this as a broad category rather than immediately distinguishing rook, pawn, queen, or minor-piece endgames.

---

## 20. Endgame Detection

Use material-based classification rather than move count alone.

Initial heuristic:

Classify as an endgame when either:

```text
both queens are absent
```

and total non-pawn material is below a configured threshold;

or:

```text
total non-pawn pieces <= 6
```

excluding kings.

Special cases should allow queen endgames later.

---

### Primary Trigger

```text
game_phase == endgame

AND

evaluation_loss >= 100 cp
```

This is intentionally simple for the MVP.

---

### Additional Metadata

Record:

```text
endgame_type
```

when identifiable.

Potential values:

```text
pawn
rook
minor_piece
rook_and_minor
queen
mixed
```

Even if these are not yet separate themes, collecting this metadata enables future analysis.

---

### Example

```text
Endgame:
Rook + 4 pawns vs Rook + 4 pawns

Played:
Kf3??

Best:
Rc7+

Evaluation:
+0.2 → -1.6
```

Result:

```text
Theme:
Endgame Mistake

Severity:
Moderate

Subtype:
rook
```

---

## 21. Preventing Duplicate Noise

One bad move may trigger several low-level rules.

The application should preserve valid overlapping themes but avoid redundant occurrences.

For example:

```text
Hanging Piece
Missed Opponent Threat
Endgame Mistake
```

may all validly describe one move.

However, the system should not generate three Hanging Piece records because three separate attack-map rules detected the same rook loss.

Deduplication key should approximately be:

```text
game_id
position_id
theme_id
```

---

## 22. Theme Prioritization

When summarizing a game, themes should be ranked by importance.

Suggested occurrence score:

```text
importance =
severity_weight
× confidence
× criticality_weight
```

Example severity weights:

```text
minor     = 1
moderate  = 2
major     = 3
severe    = 4
```

Critical positions may receive:

```text
1.0–1.5 multiplier
```

---

## 23. Review-Period Theme Score

Theme occurrence counts alone should not determine strengths or weaknesses.

For each theme calculate:

```text
occurrence count
normalized occurrence rate
average severity
average confidence
trend
sample size
```

Possible composite weakness score:

```text
weakness_score =
normalized_frequency
× average_severity
× average_confidence
```

The exact scoring formula should remain versioned.

---

## 24. Recommended Normalization

Different themes need different denominators.

### Hanging Pieces

```text
occurrences / 100 games
```

### Missed Tactical Opportunities

Prefer:

```text
misses / tactical opportunities
```

when opportunity detection is reliable.

Otherwise initially use:

```text
occurrences / 100 games
```

### Missed Opponent Threats

```text
occurrences / 100 games
```

### Poor Opening Performance

```text
poor opening outcomes / opening games
```

and separately by opening family.

### Time Trouble

```text
significant mistakes while in time trouble
/
moves played while in time trouble
```

### Moving Too Quickly

```text
fast significant mistakes
/
fast moves
```

### Lost Winning Positions

```text
lost advantages
/
winning positions reached
```

### Endgame Mistakes

```text
significant endgame mistakes
/
100 endgame decision points
```

---

## 25. Strength Detection

The same analytical system should eventually identify positive themes.

For the MVP, several strengths can be inferred as inverse performance.

Examples:

```text
High Winning Conversion
Low Hanging-Piece Rate
Strong Endgame Accuracy
Strong Opening Outcomes
Good Time Management
Strong Critical-Position Accuracy
```

A strength should require sufficient sample size.

Do not label:

```text
"Excellent Endgame Player"
```

after two endgames.

---

## 26. Minimum Sample Sizes

Initial suggestions:

| Analysis                 |             Minimum |
| ------------------------ | ------------------: |
| General theme trend      |            20 games |
| Opening-family diagnosis |             5 games |
| Conversion rate          | 5 winning positions |
| Endgame performance      |         10 endgames |
| Time-trouble performance |   20 relevant moves |
| Fast-move performance    |       20 fast moves |

Below the threshold, report:

```text
Insufficient Data
```

rather than a strong diagnosis.

---

## 27. Trend Calculation

Compare the current review period against a previous comparable period.

Use normalized rates rather than raw counts.

Example:

```text
Current:
8.2 hanging pieces / 100 games

Previous:
13.1 / 100 games

Change:
-37.4%
```

Possible classification:

```text
<= -30%     Strong Improvement
-10–30%     Improving
-10–+10%    Stable
+10–30%     Regressing
>= +30%     Strong Regression
```

Require sufficient sample size before assigning a trend label.

---

## 28. Critical Position Detection

Several classifiers benefit from knowing whether a move is critical.

Calculate:

```text
candidate_gap =
best_move_eval
-
second_best_move_eval
```

from the player's perspective.

Possible critical position:

```text
candidate_gap >= 150 cp
```

Additional critical indicators:

```text
forced mate
only move preserves equality
only move preserves advantage
large tactical swing
promotion race
king safety emergency
```

Store:

```text
critical_position: true/false
criticality_score: 0.0–1.0
```

---

## 29. Explanation Generation

Each theme occurrence should produce a deterministic explanation template before any language model is introduced.

Examples:

### Hanging Piece

```text
After {played_move}, your {piece} could be captured,
causing approximately {evaluation_loss} centipawns
of evaluation loss.
```

### Moving Too Quickly

```text
You spent approximately {move_time} seconds on this move
despite having {remaining_time} remaining.

The move changed the evaluation from
{before} to {after}.
```

### Lost Winning Position

```text
You reached a winning evaluation of {peak_eval},
but after {played_move} the advantage fell to {new_eval}.
```

These explanations are deterministic, testable, and inexpensive.

---

## 30. User Feedback

Users should eventually be able to mark a classification as:

```text
Helpful
Incorrect
Not Sure
```

Potential future options:

```text
Wrong theme
Intentional sacrifice
Known opening move
Clock data inaccurate
```

This feedback should be retained for classifier development.

---

## 31. Analysis Pipeline

Recommended sequence:

```text
PGN
 ↓
Position Reconstruction
 ↓
Stockfish Pass 1
 ↓
Critical Position Detection
 ↓
Stockfish Pass 2
 ↓
Game Phase Classification
 ↓
Board / Attack Analysis
 ↓
Theme Classifiers
 ↓
Confidence Filtering
 ↓
Deduplication
 ↓
Theme Occurrences
 ↓
Game-Level Metrics
 ↓
Review-Period Aggregation
 ↓
Trend Analysis
```

---

## 32. Theme Classifier Interface

Each classifier should implement a common interface.

Conceptually:

```python
class ThemeClassifier:
    theme_id: str
    version: str

    def detect(self, context) -> ThemeOccurrence | None:
        ...
```

Or allow multiple occurrences:

```python
def detect(context) -> list[ThemeOccurrence]:
    ...
```

Input should be a normalized `PositionContext`.

This allows new classifiers to be introduced without modifying the central analysis pipeline.

---

## 33. Suggested PositionContext

Conceptually:

```python
class PositionContext:
    game
    position

    board_before
    board_after

    played_move
    best_move

    evaluation_before
    evaluation_after
    evaluation_loss

    principal_variation
    candidate_moves

    clock
    move_time

    game_phase

    attack_map
    material

    criticality
```

Theme classifiers should consume this object rather than independently calling Stockfish.

This avoids duplicated engine work.

---

## 34. Classifier Order

Some classifiers depend on information generated by other analysis stages.

Recommended order:

```text
1. Game phase
2. Clock context
3. Material changes
4. Threat analysis
5. Tactical opportunity analysis
6. Theme detection
7. Game-level conversion detection
```

Theme classifiers themselves should remain logically independent.

---

## 35. Analysis Metadata

Every game analysis should store:

```text
stockfish_version
stockfish_settings
analysis_version
theme_engine_version
classifier_versions
```

Example:

```json
{
  "analysis_version": "1.0",
  "stockfish_version": "18",
  "stockfish_depth_scan": 14,
  "stockfish_depth_critical": 20,
  "multipv": 3,
  "theme_engine_version": "1.0"
}
```

This is essential for longitudinal comparisons.

---

## 36. Reanalysis

When classifier logic changes, existing theme occurrences should not silently change.

Instead:

```text
Old occurrences remain associated with version 1.

User/system initiates reanalysis.

New occurrences use version 2.
```

Review periods should ideally compare games analyzed using compatible versions.

---

## 37. MVP Validation

Before using a classifier to generate user-facing coaching advice, manually test it against a labeled sample.

Recommended initial test set:

```text
100–250 player mistakes
```

Manually identify whether each position represents:

```text
Hanging Piece
Tactical Miss
Opponent Threat
Opening Error
Time Trouble
Fast Move
Lost Advantage
Endgame Error
None / Other
```

Measure:

```text
precision
recall
false-positive rate
```

For the MVP, precision should matter more than recall.

A reasonable initial target for highly deterministic themes:

```text
precision >= 90%
```

Themes with lower confidence should either:

```text
remain experimental
```

or:

```text
require a higher confidence threshold.
```

---

## 38. MVP Priority Order

Classifier implementation should proceed roughly in this order:

```text
1. Time Trouble
2. Moving Too Quickly
3. Lost Winning Position
4. Endgame Mistake
5. Poor Opening Performance
6. Hanging Piece
7. Missed Tactical Opportunity
8. Missed Opponent Threat
```

The first group relies mostly on objective evaluation, clock, phase, and game-state information.

The final three require progressively more chess-specific interpretation.

This order allows the application to produce useful analytics before the hardest classification problems are solved.

---

## 39. Definition of Done

The MVP Theme Engine is complete when:

- every analyzed player move receives normalized context;
- critical positions can be identified;
- the eight MVP themes have dedicated classifiers;
- theme occurrences contain severity and confidence;
- low-confidence classifications are filtered;
- every occurrence stores supporting evidence;
- duplicate detections are eliminated;
- occurrences aggregate across review periods;
- rates are normalized;
- themes can be compared against previous periods;
- every diagnosis can link back to the position that produced it.

The central contract of the Theme Engine should be:

> **Never tell the player they have a recurring weakness unless the system can show the positions, measurements, and rules that produced that conclusion.**

That requirement should guide both MVP implementation and future theme expansion.
