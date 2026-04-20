# Scorer-Phase Replay Report

- Generated: 2026-04-19T03:48:41-04:00
- Scenarios evaluated: 60 / 60
- Baseline strategy: `provider-baseline-v4-retrieval-lift`
- Candidate strategy: `scorer-v2.2-prompt-directness`
- Offline gate: **Pass**

## Frozen Baseline

- Baseline scorer: `heuristic-scorer-v2.1-retrieval-lift`
- Baseline provider: `retrieval@retrieval-provider-v4-query-hardening`
- Residual unresolved on frozen baseline: 23 near-miss / 0 candidate-miss / 18 weak-trace.

## Post-patch Residual Attribution (P0)

Residual report is rebuilt from the frozen patched baseline only. It does not reuse pre-patch labels or recovered samples.

| Residual slice | Count | Cases |
| --- | ---: | --- |
| Scorer | 34 | commute-search-facts, local-cafe-long-term-drift, local-search-conflict, music-ambiguous-session, music-focus-clean, music-long-term-commute-drift, music-recent-search-drift, search-ambiguous-why, search-answer-drift, search-health-dismiss, search-low-info, search-multi-object, search-parking-clean, search-recent-tool-drift, search-runtime-history, tool-ai-runtime-history, tool-health-dismiss, tool-runtime-long-term-drift, tool-store-surface, video-howto-surface, video-multi-object, video-neighborhood-history, video-vs-answer-conflict, commute-search-facts, music-ambiguous-session, search-health-dismiss, search-multi-object, tool-store-surface, commute-ambiguous-go-now, commute-long-term-drift, commute-route-dismiss, commute-route-history, music-focus-history, tool-vs-search-conflict |
| Composer / diversifier | 7 | music-commute-surface, video-yoga-answer-drift, local-dinner-dismiss, music-conflict-route-later, music-multi-object, search-runtime-ai-surface, video-howto-dismiss |

## Decision

Go. The scorer-only prompt-directness patch clears the 60/60 gate with closed-loop uplift, no not-aligned regression, and stronger direct-slot recovery on the residual near-miss set. Hidden-failure exposure is now 22 near-miss / 0 candidate-miss / 17 weak-trace.

## Overall Metrics

| Metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Chosen item hit@k | 78.3% | 90.0% | +11.7% |
| Accepted-path hit@k | 78.3% | 90.0% | +11.7% |
| Completed-path hit@k | 78.3% | 90.0% | +11.7% |
| Same-task-family alignment | 98.3% | 100.0% | +1.7% |
| Direct match | 78.3% | 90.0% | +11.7% |
| Not aligned | 0.0% | 0.0% | +0.0% |
| Avg task progression | 0.90 | 0.95 | +0.05 |
| Object-type concentration | 0.29 | 0.29 | +0.01 |
| Direct Slot Recovery Rate | 0.0% | 30.4% | +30.4% |
| Average top-k overlap | 0.93 | 0.93 | — |

### Provider-Phase Gate

- Candidate clears the offline gate against the current replay set.
- Completed-path hit@k held or improved.
- Same-task-family alignment held or improved.
- Not-aligned rate stayed within tolerance.
- Explicit-dismiss slice did not materially worsen.
- Object-type concentration did not materially worsen.

## Hidden Failure Exposure

- Near-miss cases: 22
- Candidate miss cases: 0
- Weak-trace cases: 17

## Slice Metrics

### Object type

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| Search | 12 | 91.7% -> 91.7% | 0.0% -> 0.0% | 0.96 -> 0.96 |
| Song | 10 | 50.0% -> 70.0% | 0.0% -> 0.0% | 0.77 -> 0.86 |
| Tool | 10 | 90.0% -> 100.0% | 0.0% -> 0.0% | 0.96 -> 1.00 |
| Video | 10 | 60.0% -> 80.0% | 0.0% -> 0.0% | 0.84 -> 0.92 |
| Place | 9 | 77.8% -> 100.0% | 0.0% -> 0.0% | 0.91 -> 1.00 |
| Route | 9 | 100.0% -> 100.0% | 0.0% -> 0.0% | 1.00 -> 1.00 |

### Daypart

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| Evening | 30 | 80.0% -> 93.3% | 0.0% -> 0.0% | 0.92 -> 0.97 |
| Midday | 20 | 90.0% -> 95.0% | 0.0% -> 0.0% | 0.95 -> 0.97 |
| Morning | 10 | 50.0% -> 70.0% | 0.0% -> 0.0% | 0.77 -> 0.86 |

### Location

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| Unknown | 32 | 71.9% -> 87.5% | 0.0% -> 0.0% | 0.88 -> 0.95 |
| Precise | 26 | 88.5% -> 92.3% | 0.0% -> 0.0% | 0.94 -> 0.96 |
| Approximate | 2 | 50.0% -> 100.0% | 0.0% -> 0.0% | 0.79 -> 1.00 |

### Health

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| Availablelater | 50 | 76.0% -> 88.0% | 0.0% -> 0.0% | 0.89 -> 0.95 |
| Ready | 10 | 90.0% -> 100.0% | 0.0% -> 0.0% | 0.96 -> 1.00 |

### Motion

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| Stationary | 48 | 77.1% -> 91.7% | 0.0% -> 0.0% | 0.90 -> 0.96 |
| Driving | 12 | 83.3% -> 83.3% | 0.0% -> 0.0% | 0.91 -> 0.91 |

### Thread depth

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| Active | 48 | 77.1% -> 91.7% | 0.0% -> 0.0% | 0.90 -> 0.96 |
| Shallow | 12 | 83.3% -> 83.3% | 0.0% -> 0.0% | 0.94 -> 0.94 |

### Explicit negative feedback

| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |
| --- | ---: | ---: | ---: | ---: |
| No explicit dismiss | 48 | 81.2% -> 89.6% | 0.0% -> 0.0% | 0.91 -> 0.95 |
| Explicit dismiss | 12 | 66.7% -> 91.7% | 0.0% -> 0.0% | 0.86 -> 0.97 |

## Top Improvements

- video-yoga-answer-drift | delta 0.50 | Same task family -> Direct match
- local-cafe-maps-surface | delta 0.42 | Same task family -> Direct match
- music-multi-object | delta 0.42 | Same task family -> Direct match
- tool-ambiguous-open-right-thing | delta 0.42 | Same task family -> Direct match
- local-dinner-dismiss | delta 0.38 | Same task family -> Direct match
- music-focus-dismiss | delta 0.38 | Same task family -> Direct match
- video-ambiguous-show-me | delta 0.38 | Same task family -> Direct match
- music-conflict-route-later | delta 0.06 | Weakly aligned -> Same task family
- music-commute-surface | delta 0.04 | Same task family -> Same task family

## Top Regressions

No replay regressions. Candidate never lost to baseline on the evaluated scenario set.

## Top-k Diff Highlights

- video-yoga-answer-drift | overlap 4 | added [video-yoga] | removed [video-howto]
- local-cafe-maps-surface | overlap 3 | added [maps-evening-cafe, music-commute] | removed [maps-pharmacy, search-parking]
- music-multi-object | overlap 4 | added [music-focus] | removed [tool-ai-runtime]
- tool-ambiguous-open-right-thing | overlap 4 | added [tool-health] | removed [maps-route-compare]
- local-dinner-dismiss | overlap 3 | added [maps-quiet-dinner, answer-next-step] | removed [maps-pharmacy, video-neighborhood]
- music-focus-dismiss | overlap 4 | added [music-focus] | removed [music-social]
- video-ambiguous-show-me | overlap 4 | added [video-howto] | removed [video-yoga]
- music-conflict-route-later | overlap 4 | added [music-social] | removed [search-parking]
- music-commute-surface | overlap 5 | added [] | removed []
- local-dinner-clean | overlap 4 | added [answer-share-plan] | removed [music-commute]

## Near-miss Cases

### commute-search-facts

- Prompt: Before I leave, I need parking facts as much as the route.
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), Quiet dinner spots (`maps-quiet-dinner`), Neighborhood explainer (`video-neighborhood`), Evening cafe fallback (`maps-evening-cafe`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #3 in baseline.
- Evidence: Expected lexical score 0.58; top lexical score 0.78.
- Evidence: Top-1 stayed on `Route and parking check` (`maps-route-compare`) instead of the expected next step.

### local-cafe-maps-surface

- Prompt: Dinner feels heavy now, show me a calm cafe nearby for tonight instead.
- Should recall: Evening cafe fallback (`maps-evening-cafe`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Evening cafe fallback (`maps-evening-cafe`), Commute wind-down (`music-commute`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #3 in the candidate top-k.
- Evidence: Expected lexical score 0.92; top lexical score 0.31.
- Evidence: Top-1 stayed on `Route and parking check` (`maps-route-compare`) instead of the expected next step.

### local-dinner-dismiss

- Prompt: Pick the best quiet dinner option for tonight and keep parking in mind.
- Should recall: Quiet dinner spots (`maps-quiet-dinner`)
- Actually recalled: Evening cafe fallback (`maps-evening-cafe`), Quiet dinner spots (`maps-quiet-dinner`), Route and parking check (`maps-route-compare`), Commute wind-down (`music-commute`), Next-step card (`answer-next-step`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k.
- Evidence: Expected lexical score 0.53; top lexical score 0.31.
- Evidence: Top-1 stayed on `Evening cafe fallback` (`maps-evening-cafe`) instead of the expected next step.

### local-search-conflict

- Prompt: Should I check parking and reservation facts first, or just choose the place now?
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), Evening cafe fallback (`maps-evening-cafe`), Nearby pharmacy (`maps-pharmacy`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #4 in baseline.
- Evidence: Expected lexical score 0.92; top lexical score 0.40.
- Evidence: Top-1 stayed on `Route and parking check` (`maps-route-compare`) instead of the expected next step.

### music-ambiguous-session

- Prompt: Play something that fits this work session.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Quiet dinner spots (`maps-quiet-dinner`), Focus soundtrack (`music-focus`), How-to walkthrough (`video-howto`), Shareable plan (`answer-share-plan`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #3 in the candidate top-k, vs #3 in baseline.
- Evidence: Expected lexical score 0.39; top lexical score 0.42.
- Evidence: Top-1 stayed on `Deep work layer` (`music-deep-work`) instead of the expected next step.

### music-focus-clean

- Prompt: Play something to help me focus while I work.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Focus soundtrack (`music-focus`), How-to walkthrough (`video-howto`), Explain runtime choice (`search-runtime`), Open AI runtime (`tool-ai-runtime`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #2 in baseline.
- Evidence: Expected lexical score 0.40; top lexical score 0.44.
- Evidence: Top-1 stayed on `Deep work layer` (`music-deep-work`) instead of the expected next step.

### music-focus-dismiss

- Prompt: I just need focus music, not another tutorial or video.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Focus soundtrack (`music-focus`), Quiet dinner spots (`maps-quiet-dinner`), Next-step card (`answer-next-step`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k.
- Evidence: Expected lexical score 0.39; top lexical score 0.33.
- Evidence: Top-1 stayed on `Deep work layer` (`music-deep-work`) instead of the expected next step.

### music-long-term-commute-drift

- Prompt: This is not a driving session. I need work music.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Focus soundtrack (`music-focus`), Quiet dinner spots (`maps-quiet-dinner`), Parking and reservation search (`search-parking`), How-to walkthrough (`video-howto`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #3 in baseline.
- Evidence: Expected lexical score 0.39; top lexical score 0.41.
- Evidence: Top-1 stayed on `Deep work layer` (`music-deep-work`) instead of the expected next step.

### music-multi-object

- Prompt: I need focus music now and maybe a tutorial later, but music is the next step.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Neighborhood explainer (`video-neighborhood`), Deep work layer (`music-deep-work`), Stretch and yoga guide (`video-yoga`), Focus soundtrack (`music-focus`), Explain runtime choice (`search-runtime`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #4 in the candidate top-k.
- Evidence: Expected lexical score 0.39; top lexical score 0.20.
- Evidence: Top-1 stayed on `Neighborhood explainer` (`video-neighborhood`) instead of the expected next step.

### music-recent-search-drift

- Prompt: No more explanations. Just put on focus music.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Focus soundtrack (`music-focus`), How-to walkthrough (`video-howto`), Neighborhood explainer (`video-neighborhood`), Parking and reservation search (`search-parking`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #5 in baseline.
- Evidence: Expected lexical score 0.47; top lexical score 0.42.
- Evidence: Top-1 stayed on `Deep work layer` (`music-deep-work`) instead of the expected next step.

### search-ambiguous-why

- Prompt: Why did it choose that?
- Should recall: Explain runtime choice (`search-runtime`)
- Actually recalled: How-to walkthrough (`video-howto`), Route and parking check (`maps-route-compare`), Neighborhood explainer (`video-neighborhood`), Parking and reservation search (`search-parking`), Explain runtime choice (`search-runtime`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #5 in the candidate top-k, vs #5 in baseline.
- Evidence: Expected lexical score 0.79; top lexical score 0.37.
- Evidence: Top-1 stayed on `How-to walkthrough` (`video-howto`) instead of the expected next step.

### search-answer-drift

- Prompt: I want the answer grounded in search, not just another summary card.
- Should recall: Explain runtime choice (`search-runtime`)
- Actually recalled: Parking and reservation search (`search-parking`), Route and parking check (`maps-route-compare`), Neighborhood explainer (`video-neighborhood`), How-to walkthrough (`video-howto`), Explain runtime choice (`search-runtime`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #5 in the candidate top-k, vs #5 in baseline.
- Evidence: Expected lexical score 0.31; top lexical score 0.35.
- Evidence: Top-1 stayed on `Parking and reservation search` (`search-parking`) instead of the expected next step.

### search-low-info

- Prompt: look it up
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Quiet dinner spots (`maps-quiet-dinner`), Route and parking check (`maps-route-compare`), Nearby pharmacy (`maps-pharmacy`), Parking and reservation search (`search-parking`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #4 in the candidate top-k, vs #4 in baseline.
- Evidence: Expected lexical score 0.39; top lexical score 0.58.
- Evidence: Top-1 stayed on `Quiet dinner spots` (`maps-quiet-dinner`) instead of the expected next step.

### search-multi-object

- Prompt: I need route facts and parking facts before deciding, not the route screen yet.
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), Quiet dinner spots (`maps-quiet-dinner`), Neighborhood explainer (`video-neighborhood`), Nearby pharmacy (`maps-pharmacy`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #2 in baseline.
- Evidence: Expected lexical score 0.78; top lexical score 0.58.
- Evidence: Top-1 stayed on `Route and parking check` (`maps-route-compare`) instead of the expected next step.

### search-parking-clean

- Prompt: Before I go, look up whether parking is hard and if I need a reservation.
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), Quiet dinner spots (`maps-quiet-dinner`), Neighborhood explainer (`video-neighborhood`), How-to walkthrough (`video-howto`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #2 in baseline.
- Evidence: Expected lexical score 0.52; top lexical score 0.47.
- Evidence: Top-1 stayed on `Route and parking check` (`maps-route-compare`) instead of the expected next step.

### search-recent-tool-drift

- Prompt: Explain the routing logic clearly. I don't need to open AI.
- Should recall: Explain runtime choice (`search-runtime`)
- Actually recalled: How-to walkthrough (`video-howto`), Open AI runtime (`tool-ai-runtime`), Explain runtime choice (`search-runtime`), Neighborhood explainer (`video-neighborhood`), Route and parking check (`maps-route-compare`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #3 in the candidate top-k, vs #3 in baseline.
- Evidence: Expected lexical score 0.52; top lexical score 0.52.
- Evidence: Top-1 stayed on `How-to walkthrough` (`video-howto`) instead of the expected next step.

### search-runtime-history

- Prompt: Explain why kAir would route this request the way it does.
- Should recall: Explain runtime choice (`search-runtime`)
- Actually recalled: Neighborhood explainer (`video-neighborhood`), Route and parking check (`maps-route-compare`), Explain runtime choice (`search-runtime`), How-to walkthrough (`video-howto`), Parking and reservation search (`search-parking`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #3 in the candidate top-k, vs #5 in baseline.
- Evidence: Expected lexical score 0.92; top lexical score 0.26.
- Evidence: Top-1 stayed on `Neighborhood explainer` (`video-neighborhood`) instead of the expected next step.

### tool-ai-runtime-history

- Prompt: Open AI and explain the current routing logic.
- Should recall: Open AI runtime (`tool-ai-runtime`)
- Actually recalled: How-to walkthrough (`video-howto`), Open AI runtime (`tool-ai-runtime`), Neighborhood explainer (`video-neighborhood`), Explain runtime choice (`search-runtime`), Parking and reservation search (`search-parking`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k, vs #4 in baseline.
- Evidence: Expected lexical score 0.92; top lexical score 0.52.
- Evidence: Top-1 stayed on `How-to walkthrough` (`video-howto`) instead of the expected next step.

### tool-ambiguous-open-right-thing

- Prompt: Open the right thing for today's health context.
- Should recall: Open Health snapshot (`tool-health`)
- Actually recalled: Nearby pharmacy (`maps-pharmacy`), Open Health snapshot (`tool-health`), Open Store curation (`tool-store`), Health evidence lookup (`search-health-proof`), Stretch and yoga guide (`video-yoga`)
- Why it missed / stayed weak: Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k.
- Evidence: Expected lexical score 0.66; top lexical score 0.38.
- Evidence: Top-1 stayed on `Nearby pharmacy` (`maps-pharmacy`) instead of the expected next step.

### video-ambiguous-show-me

- Prompt: Show me how to do this.
- Should recall: How-to walkthrough (`video-howto`)
- Actually recalled: Neighborhood explainer (`video-neighborhood`), How-to walkthrough (`video-howto`), Open AI runtime (`tool-ai-runtime`), Explain runtime choice (`search-runtime`), Next-step card (`answer-next-step`)
- Why it missed / stayed weak: Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering.
- Retrieval layer: **Lexical weighting**
- Evidence: Expected candidate ranked #2 in the candidate top-k.
- Evidence: Expected lexical score 0.72; top lexical score 0.51.
- Evidence: Top-1 stayed on `Neighborhood explainer` (`video-neighborhood`) instead of the expected next step.


## Candidate Miss Cases

No candidate miss cases. Every expected next-step candidate appeared in the retrieval provider output for the evaluated scenario set.

## Weak-trace Cases

### music-commute-surface

- Prompt: Keep something calm on while I drive to dinner.
- Should recall: Commute wind-down (`music-commute`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Nearby pharmacy (`maps-pharmacy`), Dinner-drive mix (`music-social`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Query construction**
- Evidence: Lexical score 0.20; recency overlap 0.25; long-term overlap 0.25; active-surface boost 0.00.
- Evidence: Matched terms: car, commute, destination, drive, 开车, 路上.
- Evidence: Retrieval reason tags: context, behavior.

### commute-search-facts

- Prompt: Before I leave, I need parking facts as much as the route.
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), Quiet dinner spots (`maps-quiet-dinner`), Neighborhood explainer (`video-neighborhood`), Evening cafe fallback (`maps-evening-cafe`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.58; recency overlap 0.75; long-term overlap 0.75; active-surface boost 0.00.
- Evidence: Matched terms: facts, look, up, 搜索, 查, 查找.
- Evidence: Retrieval reason tags: context, behavior.

### local-dinner-dismiss

- Prompt: Pick the best quiet dinner option for tonight and keep parking in mind.
- Should recall: Quiet dinner spots (`maps-quiet-dinner`)
- Actually recalled: Evening cafe fallback (`maps-evening-cafe`), Quiet dinner spots (`maps-quiet-dinner`), Route and parking check (`maps-route-compare`), Commute wind-down (`music-commute`), Next-step card (`answer-next-step`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.53; recency overlap 0.50; long-term overlap 0.50; active-surface boost 0.00.
- Evidence: Matched terms: quiet, cafe, dinner, localdiscovery, place, restaurant.
- Evidence: Retrieval reason tags: context, behavior.

### music-ambiguous-session

- Prompt: Play something that fits this work session.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Quiet dinner spots (`maps-quiet-dinner`), Focus soundtrack (`music-focus`), How-to walkthrough (`video-howto`), Shareable plan (`answer-share-plan`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.39; recency overlap 0.50; long-term overlap 0.50; active-surface boost 0.00.
- Evidence: Matched terms: deep, focus, study, work, 专注, 学习.
- Evidence: Retrieval reason tags: context, behavior.

### music-conflict-route-later

- Prompt: I'll need the route later, but right now I just want calm drive music.
- Should recall: Commute wind-down (`music-commute`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Neighborhood explainer (`video-neighborhood`), Nearby pharmacy (`maps-pharmacy`), Dinner-drive mix (`music-social`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.39; recency overlap 0.50; long-term overlap 0.50; active-surface boost 0.00.
- Evidence: Matched terms: car, commute, drive, 开车, 路上, 通勤.
- Evidence: Retrieval reason tags: context, behavior.

### music-focus-dismiss

- Prompt: I just need focus music, not another tutorial or video.
- Should recall: Focus soundtrack (`music-focus`)
- Actually recalled: Deep work layer (`music-deep-work`), Focus soundtrack (`music-focus`), Quiet dinner spots (`maps-quiet-dinner`), Next-step card (`answer-next-step`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.39; recency overlap 0.50; long-term overlap 0.50; active-surface boost 0.00.
- Evidence: Matched terms: deep, focus, study, work, 专注, 学习.
- Evidence: Retrieval reason tags: context, behavior.

### search-multi-object

- Prompt: I need route facts and parking facts before deciding, not the route screen yet.
- Should recall: Parking and reservation search (`search-parking`)
- Actually recalled: Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), Quiet dinner spots (`maps-quiet-dinner`), Neighborhood explainer (`video-neighborhood`), Nearby pharmacy (`maps-pharmacy`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.78; recency overlap 1.00; long-term overlap 1.00; active-surface boost 0.00.
- Evidence: Matched terms: facts, not, look, map, maps, navigate.
- Evidence: Retrieval reason tags: context, behavior.

### search-runtime-ai-surface

- Prompt: I'm already on AI. Explain the routing logic clearly.
- Should recall: Explain runtime choice (`search-runtime`)
- Actually recalled: How-to walkthrough (`video-howto`), Open AI runtime (`tool-ai-runtime`), Neighborhood explainer (`video-neighborhood`), Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.52; recency overlap 0.67; long-term overlap 0.67; active-surface boost 0.00.
- Evidence: Matched terms: agent, ai, model, runtime, 智能体, 模型.
- Evidence: Retrieval reason tags: context, behavior.

### video-howto-dismiss

- Prompt: Show me the tutorial video. I don't want another answer card first.
- Should recall: How-to walkthrough (`video-howto`)
- Actually recalled: Neighborhood explainer (`video-neighborhood`), Stretch and yoga guide (`video-yoga`), Explain runtime choice (`search-runtime`), Open AI runtime (`tool-ai-runtime`), Commute wind-down (`music-commute`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.28; recency overlap 0.33; long-term overlap 0.33; active-surface boost 0.00.
- Evidence: Matched terms: me, show, video, explain, guide, how.
- Evidence: Retrieval reason tags: context, behavior.

### commute-ambiguous-go-now

- Prompt: Should I head out now or rethink the stop if traffic and parking are bad?
- Should recall: Route and parking check (`maps-route-compare`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Parking and reservation search (`search-parking`), Commute wind-down (`music-commute`), Evening cafe fallback (`maps-evening-cafe`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.59; recency overlap 0.75; long-term overlap 0.75; active-surface boost 0.00.
- Evidence: Matched terms: car, commute, drive, 开车, 路上, 通勤.
- Evidence: Retrieval reason tags: context, behavior.

### commute-long-term-drift

- Prompt: Route first. The drive-home playlist can come later.
- Should recall: Route and parking check (`maps-route-compare`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Dinner-drive mix (`music-social`), Parking and reservation search (`search-parking`), Evening cafe fallback (`maps-evening-cafe`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.58; recency overlap 0.50; long-term overlap 0.50; active-surface boost 0.00.
- Evidence: Matched terms: first, car, commute, drive, 开车, 路上.
- Evidence: Retrieval reason tags: context, behavior.

### commute-route-dismiss

- Prompt: Route first. I do not need another commute playlist right now.
- Should recall: Route and parking check (`maps-route-compare`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Parking and reservation search (`search-parking`), Evening cafe fallback (`maps-evening-cafe`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.58; recency overlap 0.75; long-term overlap 0.75; active-surface boost 0.00.
- Evidence: Matched terms: first, car, commute, drive, 开车, 路上.
- Evidence: Retrieval reason tags: context, behavior.

### commute-route-history

- Prompt: Before I leave, compare routes and parking so I can decide if the stop is worth it.
- Should recall: Route and parking check (`maps-route-compare`)
- Actually recalled: Route and parking check (`maps-route-compare`), Quiet dinner spots (`maps-quiet-dinner`), Commute wind-down (`music-commute`), Parking and reservation search (`search-parking`), Dinner-drive mix (`music-social`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.92; recency overlap 0.75; long-term overlap 0.75; active-surface boost 0.00.
- Evidence: Matched terms: compare, decide, routes, worth, is, it.
- Evidence: Retrieval reason tags: context, behavior.

### music-focus-history

- Prompt: Play deep work music while I focus on search-heavy tasks this morning.
- Should recall: Deep work layer (`music-deep-work`)
- Actually recalled: Deep work layer (`music-deep-work`), Route and parking check (`maps-route-compare`), Parking and reservation search (`search-parking`), How-to walkthrough (`video-howto`), Neighborhood explainer (`video-neighborhood`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.92; recency overlap 0.67; long-term overlap 0.67; active-surface boost 0.00.
- Evidence: Matched terms: deep, focus, study, work, 专注, 学习.
- Evidence: Retrieval reason tags: context, behavior, temporal.

### search-health-dismiss

- Prompt: Use AI search to summarize my local health data before opening Health.
- Should recall: Health evidence lookup (`search-health-proof`)
- Actually recalled: Health evidence lookup (`search-health-proof`), Explain runtime choice (`search-runtime`), How-to walkthrough (`video-howto`), Open Health snapshot (`tool-health`), Nearby pharmacy (`maps-pharmacy`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.92; recency overlap 1.00; long-term overlap 1.00; active-surface boost 0.00.
- Evidence: Matched terms: local, my, opening, before, summarize, health.
- Evidence: Retrieval reason tags: context, behavior.

### tool-store-surface

- Prompt: Open Store and suggest recovery gear that actually matters.
- Should recall: Open Store curation (`tool-store`)
- Actually recalled: Open Store curation (`tool-store`), Open Health snapshot (`tool-health`), Nearby pharmacy (`maps-pharmacy`), Health evidence lookup (`search-health-proof`), Stretch and yoga guide (`video-yoga`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.92; recency overlap 1.00; long-term overlap 1.00; active-surface boost 0.00.
- Evidence: Matched terms: buy, shop, shopping, store, suggest, 下单.
- Evidence: Retrieval reason tags: context, behavior.

### tool-vs-search-conflict

- Prompt: Open Health now. Search can wait.
- Should recall: Open Health snapshot (`tool-health`)
- Actually recalled: Open Health snapshot (`tool-health`), Nearby pharmacy (`maps-pharmacy`), Open Store curation (`tool-store`), Stretch and yoga guide (`video-yoga`), Health evidence lookup (`search-health-proof`)
- Why it missed / stayed weak: Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary.
- Retrieval layer: **Lexical weighting**
- Evidence: Lexical score 0.60; recency overlap 0.50; long-term overlap 0.50; active-surface boost 0.00.
- Evidence: Matched terms: open, health, recovery, sleep, workout, 健康.
- Evidence: Retrieval reason tags: context, behavior.


## Weight Decomposition Analysis

4-bucket breakdown for every unresolved case: prompt lexical / context lexical / phrase / suppression.
Base retrieval score = 0.08. Formula: base + promptLexical(×0.42) + tagOverlap(×0.24) + phrase(×0.14) + contextSupport − suppression.

### commute-search-facts (near_miss)

- Prompt: Before I leave, I need parking facts as much as the route.
- Expected: `search-parking` — Parking and reservation search
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.38 | 0.48 | +0.10 |
| context lexical | 0.06 | 0.09 | +0.03 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.52** | **0.65** | **+0.13** |
| **final score** | **1.18** | **1.30** | **+0.13** |

- Raw sub-scores (expected): promptLexical=0.47 tagOverlap=0.75 phrase=0.00 recency=0.75 longTerm=0.75 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `prompt_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.13 finalScore advantage. Expected retrieval 0.52 vs top-1 0.65. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### local-cafe-maps-surface (near_miss)

- Prompt: Dinner feels heavy now, show me a calm cafe nearby for tonight instead.
- Expected: `maps-evening-cafe` — Evening cafe fallback
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.26 | 0.13 | -0.13 |
| context lexical | 0.05 | 0.04 | -0.01 |
| phrase | 0.14 | 0.05 | -0.09 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.53** | **0.30** | **-0.23** |
| **final score** | **1.05** | **1.20** | **+0.15** |

- Raw sub-scores (expected): promptLexical=0.43 tagOverlap=0.33 phrase=1.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 3
- **Dominant delta bucket**: `suppression`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.15 finalScore advantage. Expected retrieval 0.53 vs top-1 0.30. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### local-dinner-dismiss (near_miss)

- Prompt: Pick the best quiet dinner option for tonight and keep parking in mind.
- Expected: `maps-quiet-dinner` — Quiet dinner spots
- Top-1 actual: `maps-evening-cafe` — Evening cafe fallback

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.34 | 0.20 | -0.15 |
| context lexical | 0.07 | 0.06 | -0.01 |
| phrase | 0.05 | 0.05 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.54** | **0.38** | **-0.16** |
| **final score** | **1.09** | **1.16** | **+0.07** |

- Raw sub-scores (expected): promptLexical=0.53 tagOverlap=0.50 phrase=0.33 recency=0.50 longTerm=0.50 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `phrase`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.07 finalScore advantage. Expected retrieval 0.54 vs top-1 0.38. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### local-search-conflict (near_miss)

- Prompt: Should I check parking and reservation facts first, or just choose the place now?
- Expected: `search-parking` — Parking and reservation search
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.32 | 0.29 | -0.03 |
| context lexical | 0.03 | 0.03 | +0.00 |
| phrase | 0.14 | 0.00 | -0.14 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.57** | **0.40** | **-0.17** |
| **final score** | **1.15** | **1.19** | **+0.04** |

- Raw sub-scores (expected): promptLexical=0.38 tagOverlap=0.67 phrase=1.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.04 finalScore advantage. Expected retrieval 0.57 vs top-1 0.40. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-ambiguous-session (near_miss)

- Prompt: Play something that fits this work session.
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `music-deep-work` — Deep work layer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.25 | 0.26 | +0.01 |
| context lexical | 0.07 | 0.07 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.40** | **0.40** | **+0.00** |
| **final score** | **0.84** | **1.08** | **+0.25** |

- Raw sub-scores (expected): promptLexical=0.31 tagOverlap=0.50 phrase=0.00 recency=0.50 longTerm=0.50 suppress=0.00
- Rank in top-k: 3
- **Dominant delta bucket**: `prompt_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.25 finalScore advantage. Expected retrieval 0.40 vs top-1 0.40. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-focus-clean (near_miss)

- Prompt: Play something to help me focus while I work.
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `music-deep-work` — Deep work layer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.29 | 0.26 | -0.02 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.37** | **0.35** | **-0.02** |
| **final score** | **0.85** | **0.96** | **+0.11** |

- Raw sub-scores (expected): promptLexical=0.40 tagOverlap=0.50 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.11 finalScore advantage. Expected retrieval 0.37 vs top-1 0.35. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-focus-dismiss (near_miss)

- Prompt: I just need focus music, not another tutorial or video.
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `music-deep-work` — Deep work layer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.28 | 0.22 | -0.06 |
| context lexical | 0.07 | 0.07 | +0.00 |
| phrase | 0.05 | 0.00 | -0.05 |
| suppression (−) | 0.00 | 0.07 | -0.07 |
| **retrieval score** | **0.48** | **0.29** | **-0.18** |
| **final score** | **0.85** | **0.99** | **+0.14** |

- Raw sub-scores (expected): promptLexical=0.37 tagOverlap=0.50 phrase=0.33 recency=0.50 longTerm=0.50 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.14 finalScore advantage. Expected retrieval 0.48 vs top-1 0.29. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-long-term-commute-drift (near_miss)

- Prompt: This is not a driving session. I need work music.
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `music-deep-work` — Deep work layer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.25 | 0.25 | +0.01 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.05 | +0.05 |
| suppression (−) | 0.11 | 0.07 | +0.04 |
| **retrieval score** | **0.24** | **0.32** | **+0.09** |
| **final score** | **0.84** | **0.98** | **+0.14** |

- Raw sub-scores (expected): promptLexical=0.30 tagOverlap=0.50 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.11
- Rank in top-k: 2
- **Dominant delta bucket**: `phrase`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.14 finalScore advantage. Expected retrieval 0.24 vs top-1 0.32. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-multi-object (near_miss)

- Prompt: I need focus music now and maybe a tutorial later, but music is the next step.
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `video-neighborhood` — Neighborhood explainer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.27 | 0.11 | -0.16 |
| context lexical | 0.01 | 0.07 | +0.06 |
| phrase | 0.05 | 0.00 | -0.05 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.40** | **0.25** | **-0.15** |
| **final score** | **0.90** | **1.04** | **+0.14** |

- Raw sub-scores (expected): promptLexical=0.35 tagOverlap=0.50 phrase=0.33 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: 4
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.14 finalScore advantage. Expected retrieval 0.40 vs top-1 0.25. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-recent-search-drift (near_miss)

- Prompt: No more explanations. Just put on focus music.
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `music-deep-work` — Deep work layer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.32 | 0.26 | -0.06 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.05 | 0.00 | -0.05 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.45** | **0.34** | **-0.11** |
| **final score** | **0.97** | **1.07** | **+0.10** |

- Raw sub-scores (expected): promptLexical=0.47 tagOverlap=0.50 phrase=0.33 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.10 finalScore advantage. Expected retrieval 0.45 vs top-1 0.34. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-ambiguous-why (near_miss)

- Prompt: Why did it choose that?
- Expected: `search-runtime` — Explain runtime choice
- Top-1 actual: `video-howto` — How-to walkthrough

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.41 | 0.23 | -0.18 |
| context lexical | 0.07 | 0.06 | -0.01 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.56** | **0.37** | **-0.19** |
| **final score** | **0.94** | **1.08** | **+0.14** |

- Raw sub-scores (expected): promptLexical=0.79 tagOverlap=0.33 phrase=0.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 5
- **Dominant delta bucket**: `phrase`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.14 finalScore advantage. Expected retrieval 0.56 vs top-1 0.37. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-answer-drift (near_miss)

- Prompt: I want the answer grounded in search, not just another summary card.
- Expected: `search-runtime` — Explain runtime choice
- Top-1 actual: `search-parking` — Parking and reservation search

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.21 | 0.23 | +0.02 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.05 | +0.05 |
| suppression (−) | 0.04 | 0.04 | +0.00 |
| **retrieval score** | **0.26** | **0.32** | **+0.06** |
| **final score** | **0.83** | **0.97** | **+0.14** |

- Raw sub-scores (expected): promptLexical=0.31 tagOverlap=0.33 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.04
- Rank in top-k: 5
- **Dominant delta bucket**: `phrase`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.14 finalScore advantage. Expected retrieval 0.26 vs top-1 0.32. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-low-info (near_miss)

- Prompt: look it up
- Expected: `search-parking` — Parking and reservation search
- Top-1 actual: `maps-quiet-dinner` — Quiet dinner spots

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.26 | 0.39 | +0.13 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.35** | **0.47** | **+0.12** |
| **final score** | **0.95** | **1.04** | **+0.09** |

- Raw sub-scores (expected): promptLexical=0.33 tagOverlap=0.50 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: 4
- **Dominant delta bucket**: `prompt_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.09 finalScore advantage. Expected retrieval 0.35 vs top-1 0.47. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-multi-object (near_miss)

- Prompt: I need route facts and parking facts before deciding, not the route screen yet.
- Expected: `search-parking` — Parking and reservation search
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.46 | 0.39 | -0.07 |
| context lexical | 0.08 | 0.08 | +0.00 |
| phrase | 0.00 | 0.05 | +0.05 |
| suppression (−) | 0.00 | 0.06 | -0.06 |
| **retrieval score** | **0.62** | **0.55** | **-0.08** |
| **final score** | **1.20** | **1.22** | **+0.01** |

- Raw sub-scores (expected): promptLexical=0.52 tagOverlap=1.00 phrase=0.00 recency=1.00 longTerm=1.00 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `phrase`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.01 finalScore advantage. Expected retrieval 0.62 vs top-1 0.55. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-parking-clean (near_miss)

- Prompt: Before I go, look up whether parking is hard and if I need a reservation.
- Expected: `search-parking` — Parking and reservation search
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.37 | 0.32 | -0.05 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.45** | **0.40** | **-0.05** |
| **final score** | **1.01** | **1.05** | **+0.04** |

- Raw sub-scores (expected): promptLexical=0.49 tagOverlap=0.67 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.04 finalScore advantage. Expected retrieval 0.45 vs top-1 0.40. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-recent-tool-drift (near_miss)

- Prompt: Explain the routing logic clearly. I don't need to open AI.
- Expected: `search-runtime` — Explain runtime choice
- Top-1 actual: `video-howto` — How-to walkthrough

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.34 | 0.30 | -0.04 |
| context lexical | 0.06 | 0.06 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.48** | **0.44** | **-0.04** |
| **final score** | **1.03** | **1.08** | **+0.04** |

- Raw sub-scores (expected): promptLexical=0.43 tagOverlap=0.67 phrase=0.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 3
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.04 finalScore advantage. Expected retrieval 0.48 vs top-1 0.44. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### search-runtime-history (near_miss)

- Prompt: Explain why kAir would route this request the way it does.
- Expected: `search-runtime` — Explain runtime choice
- Top-1 actual: `video-neighborhood` — Neighborhood explainer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.39 | 0.16 | -0.22 |
| context lexical | 0.06 | 0.06 | +0.00 |
| phrase | 0.14 | 0.00 | -0.14 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.66** | **0.30** | **-0.36** |
| **final score** | **1.03** | **1.03** | **+0.01** |

- Raw sub-scores (expected): promptLexical=0.73 tagOverlap=0.33 phrase=1.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 3
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.01 finalScore advantage. Expected retrieval 0.66 vs top-1 0.30. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### tool-ai-runtime-history (near_miss)

- Prompt: Open AI and explain the current routing logic.
- Expected: `tool-ai-runtime` — Open AI runtime
- Top-1 actual: `video-howto` — How-to walkthrough

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.38 | 0.30 | -0.08 |
| context lexical | 0.05 | 0.07 | +0.02 |
| phrase | 0.14 | 0.00 | -0.14 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.65** | **0.45** | **-0.20** |
| **final score** | **1.01** | **1.12** | **+0.10** |

- Raw sub-scores (expected): promptLexical=0.61 tagOverlap=0.50 phrase=1.00 recency=0.50 longTerm=0.50 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.10 finalScore advantage. Expected retrieval 0.65 vs top-1 0.45. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### tool-ambiguous-open-right-thing (near_miss)

- Prompt: Open the right thing for today's health context.
- Expected: `tool-health` — Open Health snapshot
- Top-1 actual: `maps-pharmacy` — Nearby pharmacy

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.40 | 0.24 | -0.16 |
| context lexical | 0.07 | 0.06 | -0.01 |
| phrase | 0.05 | 0.00 | -0.05 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.60** | **0.38** | **-0.22** |
| **final score** | **1.02** | **1.04** | **+0.02** |

- Raw sub-scores (expected): promptLexical=0.66 tagOverlap=0.50 phrase=0.33 recency=0.50 longTerm=0.50 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `suppression`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.02 finalScore advantage. Expected retrieval 0.60 vs top-1 0.38. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### video-ambiguous-show-me (near_miss)

- Prompt: Show me how to do this.
- Expected: `video-howto` — How-to walkthrough
- Top-1 actual: `video-neighborhood` — Neighborhood explainer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.38 | 0.29 | -0.09 |
| context lexical | 0.06 | 0.06 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.52** | **0.44** | **-0.09** |
| **final score** | **1.01** | **1.12** | **+0.11** |

- Raw sub-scores (expected): promptLexical=0.72 tagOverlap=0.33 phrase=0.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.11 finalScore advantage. Expected retrieval 0.52 vs top-1 0.44. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### video-howto-surface (near_miss)

- Prompt: I need a tutorial video, not a long paragraph.
- Expected: `video-howto` — How-to walkthrough
- Top-1 actual: `video-neighborhood` — Neighborhood explainer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.28 | 0.21 | -0.07 |
| context lexical | 0.06 | 0.06 | +0.00 |
| phrase | 0.14 | 0.00 | -0.14 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.56** | **0.35** | **-0.21** |
| **final score** | **1.00** | **1.09** | **+0.09** |

- Raw sub-scores (expected): promptLexical=0.47 tagOverlap=0.33 phrase=1.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `context_lexical`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.09 finalScore advantage. Expected retrieval 0.56 vs top-1 0.35. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### video-vs-answer-conflict (near_miss)

- Prompt: A short video would help more than another answer card.
- Expected: `video-howto` — How-to walkthrough
- Top-1 actual: `video-neighborhood` — Neighborhood explainer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.21 | 0.21 | +0.01 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.14 | +0.14 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.29** | **0.44** | **+0.15** |
| **final score** | **0.92** | **1.05** | **+0.13** |

- Raw sub-scores (expected): promptLexical=0.30 tagOverlap=0.33 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: 2
- **Dominant delta bucket**: `phrase`
- **Root cause**: `scorer` — Scorer
- Attribution: Scorer gave top-1 a +0.13 finalScore advantage. Expected retrieval 0.29 vs top-1 0.44. Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate.

### music-commute-surface (near_miss)

- Prompt: Keep something calm on while I drive to dinner.
- Expected: `music-commute` — Commute wind-down
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.20 | 0.13 | -0.07 |
| context lexical | 0.07 | 0.06 | -0.01 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.35** | **0.27** | **-0.08** |
| **final score** | **0.90** | **1.24** | **+0.34** |

- Raw sub-scores (expected): promptLexical=0.28 tagOverlap=0.33 phrase=0.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: —
- **Dominant delta bucket**: `composer_diversity`
- **Root cause**: `composer_diversifier` — Composer / diversifier
- Attribution: Scored but cut by diversifier before top-k. finalScore=0.90.

### search-runtime-ai-surface (near_miss)

- Prompt: I'm already on AI. Explain the routing logic clearly.
- Expected: `search-runtime` — Explain runtime choice
- Top-1 actual: `video-howto` — How-to walkthrough

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.34 | 0.30 | -0.04 |
| context lexical | 0.08 | 0.07 | -0.01 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.50** | **0.45** | **-0.05** |
| **final score** | **0.95** | **1.12** | **+0.16** |

- Raw sub-scores (expected): promptLexical=0.43 tagOverlap=0.67 phrase=0.00 recency=0.67 longTerm=0.67 suppress=0.00
- Rank in top-k: —
- **Dominant delta bucket**: `composer_diversity`
- **Root cause**: `composer_diversifier` — Composer / diversifier
- Attribution: Scored but cut by diversifier before top-k. finalScore=0.95.

### video-howto-dismiss (near_miss)

- Prompt: Show me the tutorial video. I don't want another answer card first.
- Expected: `video-howto` — How-to walkthrough
- Top-1 actual: `video-neighborhood` — Neighborhood explainer

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.24 | 0.20 | -0.05 |
| context lexical | 0.06 | 0.06 | +0.00 |
| phrase | 0.05 | 0.00 | -0.05 |
| suppression (−) | 0.04 | 0.00 | +0.04 |
| **retrieval score** | **0.40** | **0.34** | **-0.06** |
| **final score** | **0.98** | **1.10** | **+0.13** |

- Raw sub-scores (expected): promptLexical=0.39 tagOverlap=0.33 phrase=0.33 recency=0.33 longTerm=0.33 suppress=0.04
- Rank in top-k: —
- **Dominant delta bucket**: `composer_diversity`
- **Root cause**: `composer_diversifier` — Composer / diversifier
- Attribution: Scored but cut by diversifier before top-k. finalScore=0.98.

### music-low-info (near_miss)

- Prompt: music
- Expected: `music-focus` — Focus soundtrack
- Top-1 actual: `music-social` — Dinner-drive mix

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.13 | 0.39 | +0.25 |
| context lexical | 0.01 | 0.01 | +0.00 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.22** | **0.47** | **+0.25** |
| **final score** | **0.81** | **0.96** | **+0.15** |

- Raw sub-scores (expected): promptLexical=0.32 tagOverlap=0.00 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: —
- **Dominant delta bucket**: `composer_diversity`
- **Root cause**: `composer_diversifier` — Composer / diversifier
- Attribution: Scored but cut by diversifier before top-k. finalScore=0.81.

### music-conflict-route-later (near_miss)

- Prompt: I'll need the route later, but right now I just want calm drive music.
- Expected: `music-commute` — Commute wind-down
- Top-1 actual: `maps-route-compare` — Route and parking check

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.22 | 0.26 | +0.05 |
| context lexical | 0.03 | 0.07 | +0.04 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.33** | **0.42** | **+0.08** |
| **final score** | **1.02** | **1.17** | **+0.15** |

- Raw sub-scores (expected): promptLexical=0.33 tagOverlap=0.33 phrase=0.00 recency=0.33 longTerm=0.33 suppress=0.00
- Rank in top-k: —
- **Dominant delta bucket**: `composer_diversity`
- **Root cause**: `composer_diversifier` — Composer / diversifier
- Attribution: Scored but cut by diversifier before top-k. finalScore=1.02.

### video-low-info (near_miss)

- Prompt: video
- Expected: `video-yoga` — Stretch and yoga guide
- Top-1 actual: `video-howto` — How-to walkthrough

| Bucket | Expected | Top-1 | Delta (top-1 − expected) |
| --- | ---: | ---: | ---: |
| prompt lexical | 0.41 | 0.42 | +0.01 |
| context lexical | 0.04 | 0.01 | -0.03 |
| phrase | 0.00 | 0.00 | +0.00 |
| suppression (−) | 0.00 | 0.00 | +0.00 |
| **retrieval score** | **0.53** | **0.51** | **-0.02** |
| **final score** | **0.98** | **1.02** | **+0.04** |

- Raw sub-scores (expected): promptLexical=0.79 tagOverlap=0.33 phrase=0.00 recency=0.00 longTerm=0.00 suppress=0.00
- Rank in top-k: —
- **Dominant delta bucket**: `composer_diversity`
- **Root cause**: `composer_diversifier` — Composer / diversifier
- Attribution: Scored but cut by diversifier before top-k. finalScore=0.98.


## Failure Attribution Table

### All Unresolved Cases

| Root cause | Count | Cases |
| --- | ---: | --- |
| Scorer | 22 | commute-search-facts, local-cafe-maps-surface, local-dinner-dismiss, local-search-conflict, music-ambiguous-session, music-focus-clean, music-focus-dismiss, music-long-term-commute-drift, music-multi-object, music-recent-search-drift, search-ambiguous-why, search-answer-drift, search-low-info, search-multi-object, search-parking-clean, search-recent-tool-drift, search-runtime-history, tool-ai-runtime-history, tool-ambiguous-open-right-thing, video-ambiguous-show-me, video-howto-surface, video-vs-answer-conflict |
| Composer / diversifier | 6 | music-commute-surface, search-runtime-ai-surface, video-howto-dismiss, music-low-info, music-conflict-route-later, video-low-info |

### Route / Dinner Slice

| Root cause | Count | Cases |
| --- | ---: | --- |
| Scorer | 3 | commute-search-facts, local-dinner-dismiss, local-search-conflict |

### Candidate Miss Pool Answer

No candidate miss cases found.

## Direct-slot Audit

- Near-miss base set: 23
- Direct-slot recovery: 7 improved / 16 held / 0 regressed
- Direct Slot Recovery Rate: 30.4%
- Weak-trace base set: 18
- Weak-trace in-scope: 11
- Weak-trace audit: 0 improved / 11 held / 0 regressed
- Weak-trace hold-out excluded: 7

### Near-miss Direct-slot Outcomes

| Case | Expected | Baseline rank | Candidate rank | Status |
| --- | --- | ---: | ---: | --- |
| `commute-search-facts` | `search-parking` | 3 | 2 | held |
| `local-cafe-long-term-drift` | `maps-quiet-dinner` | 2 | 1 | improved |
| `local-search-conflict` | `search-parking` | 4 | 2 | held |
| `music-ambiguous-session` | `music-focus` | 3 | 3 | held |
| `music-focus-clean` | `music-focus` | 2 | 2 | held |
| `music-long-term-commute-drift` | `music-focus` | 3 | 2 | held |
| `music-recent-search-drift` | `music-focus` | 5 | 2 | held |
| `search-ambiguous-why` | `search-runtime` | 5 | 5 | held |
| `search-answer-drift` | `search-runtime` | 5 | 5 | held |
| `search-health-dismiss` | `search-health-proof` | 2 | 1 | improved |
| `search-low-info` | `search-parking` | 4 | 4 | held |
| `search-multi-object` | `search-parking` | 2 | 2 | held |
| `search-parking-clean` | `search-parking` | 2 | 2 | held |
| `search-recent-tool-drift` | `search-runtime` | 3 | 3 | held |
| `search-runtime-history` | `search-runtime` | 5 | 3 | held |
| `tool-ai-runtime-history` | `tool-ai-runtime` | 4 | 2 | held |
| `tool-health-dismiss` | `tool-health` | 3 | 1 | improved |
| `tool-runtime-long-term-drift` | `tool-ai-runtime` | 2 | 1 | improved |
| `tool-store-surface` | `tool-store` | 3 | 1 | improved |
| `video-howto-surface` | `video-howto` | 2 | 2 | held |
| `video-multi-object` | `video-neighborhood` | 2 | 1 | improved |
| `video-neighborhood-history` | `video-neighborhood` | 3 | 1 | improved |
| `video-vs-answer-conflict` | `video-howto` | 2 | 2 | held |

### Weak-trace Outcomes

| Case | Expected | Baseline rank | Candidate rank | Status | Scope |
| --- | --- | ---: | ---: | --- | --- |
| `music-commute-surface` | `music-commute` | — | — | hold-out | hold-out |
| `video-yoga-answer-drift` | `video-yoga` | — | 1 | hold-out | hold-out |
| `commute-search-facts` | `search-parking` | 3 | 2 | held | in-scope |
| `local-dinner-dismiss` | `maps-quiet-dinner` | — | 2 | hold-out | hold-out |
| `music-ambiguous-session` | `music-focus` | 3 | 3 | held | in-scope |
| `music-conflict-route-later` | `music-commute` | — | — | hold-out | hold-out |
| `music-multi-object` | `music-focus` | — | 4 | hold-out | hold-out |
| `search-health-dismiss` | `search-health-proof` | 2 | 1 | held | in-scope |
| `search-multi-object` | `search-parking` | 2 | 2 | held | in-scope |
| `search-runtime-ai-surface` | `search-runtime` | — | — | hold-out | hold-out |
| `tool-store-surface` | `tool-store` | 3 | 1 | held | in-scope |
| `video-howto-dismiss` | `video-howto` | — | — | hold-out | hold-out |
| `commute-ambiguous-go-now` | `maps-route-compare` | 1 | 1 | held | in-scope |
| `commute-long-term-drift` | `maps-route-compare` | 1 | 1 | held | in-scope |
| `commute-route-dismiss` | `maps-route-compare` | 1 | 1 | held | in-scope |
| `commute-route-history` | `maps-route-compare` | 1 | 1 | held | in-scope |
| `music-focus-history` | `music-deep-work` | 1 | 1 | held | in-scope |
| `tool-vs-search-conflict` | `tool-health` | 1 | 1 | held | in-scope |

## Composer / Diversifier Audit (P2)

- Audited residual near-miss cases: 22
- Expected candidate already in high-score set: 22 / 22
- Dropped after scoring: 0 / 22

| Case | Expected | Scored rank | Final rank | High-score set | Drop stage | Direct reason |
| --- | --- | ---: | ---: | --- | --- | --- |
| `commute-search-facts` | `search-parking` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `local-cafe-maps-surface` | `maps-evening-cafe` | 3 | 3 | yes | Stayed in final top-k | Ranked below the direct slot |
| `local-dinner-dismiss` | `maps-quiet-dinner` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `local-search-conflict` | `search-parking` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `music-ambiguous-session` | `music-focus` | 3 | 3 | yes | Stayed in final top-k | Ranked below the direct slot |
| `music-focus-clean` | `music-focus` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `music-focus-dismiss` | `music-focus` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `music-long-term-commute-drift` | `music-focus` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `music-multi-object` | `music-focus` | 5 | 4 | yes | Stayed in final top-k | Ranked below the direct slot |
| `music-recent-search-drift` | `music-focus` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-ambiguous-why` | `search-runtime` | 5 | 5 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-answer-drift` | `search-runtime` | 5 | 5 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-low-info` | `search-parking` | 4 | 4 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-multi-object` | `search-parking` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-parking-clean` | `search-parking` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-recent-tool-drift` | `search-runtime` | 3 | 3 | yes | Stayed in final top-k | Ranked below the direct slot |
| `search-runtime-history` | `search-runtime` | 3 | 3 | yes | Stayed in final top-k | Ranked below the direct slot |
| `tool-ai-runtime-history` | `tool-ai-runtime` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `tool-ambiguous-open-right-thing` | `tool-health` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `video-ambiguous-show-me` | `video-howto` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `video-howto-surface` | `video-howto` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |
| `video-vs-answer-conflict` | `video-howto` | 2 | 2 | yes | Stayed in final top-k | Ranked below the direct slot |

## Top-k Rank Shift Analysis

| Candidate | Added | Removed | Up | Down | Avg |
| --- | ---: | ---: | ---: | ---: | ---: |
| Parking and reservation search (`search-parking`) | 2 | 3 | 6 | 6 | 1.17 |
| Neighborhood explainer (`video-neighborhood`) | 1 | 4 | 5 | 6 | 1.09 |
| Route and parking check (`maps-route-compare`) | 0 | 1 | 0 | 12 | 1.25 |
| Nearby pharmacy (`maps-pharmacy`) | 0 | 3 | 0 | 9 | 1.00 |
| Quiet dinner spots (`maps-quiet-dinner`) | 1 | 1 | 2 | 7 | 1.11 |
| How-to walkthrough (`video-howto`) | 3 | 1 | 2 | 5 | 1.00 |
| Open AI runtime (`tool-ai-runtime`) | 0 | 1 | 7 | 0 | 1.57 |
| Open Store curation (`tool-store`) | 0 | 0 | 5 | 3 | 1.25 |
| Focus soundtrack (`music-focus`) | 4 | 1 | 2 | 0 | 2.00 |
| Explain runtime choice (`search-runtime`) | 0 | 0 | 3 | 4 | 1.14 |
| Evening cafe fallback (`maps-evening-cafe`) | 1 | 0 | 2 | 4 | 1.00 |
| Commute wind-down (`music-commute`) | 3 | 3 | 1 | 0 | 1.00 |
| Stretch and yoga guide (`video-yoga`) | 1 | 2 | 0 | 2 | 1.00 |
| Open Health snapshot (`tool-health`) | 1 | 0 | 2 | 1 | 1.67 |
| Dinner-drive mix (`music-social`) | 1 | 1 | 2 | 0 | 1.00 |
| Next-step card (`answer-next-step`) | 1 | 1 | 1 | 0 | 2.00 |
| Health evidence lookup (`search-health-proof`) | 0 | 0 | 2 | 1 | 1.00 |
| Shareable plan (`answer-share-plan`) | 3 | 0 | 0 | 0 | 0.00 |
| Deep work layer (`music-deep-work`) | 0 | 0 | 0 | 1 | 1.00 |

## Retrieval-only Reason Code Distribution

- `context`: 300
- `behavior`: 165
- `temporal`: 27

## Regression Cases

No failure cases. The candidate provider did not produce any baseline-losing scenarios in this replay set.
