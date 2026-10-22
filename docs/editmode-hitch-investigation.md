# Edit Mode hitch investigation

Opening Edit Mode causes a visible hitch and FPS drop with SeamlessUI enabled.
Disabling its options has not resolved it. Focus and target-of-target changes are
suspected, but no timing evidence establishes the cause yet.

## Diagnostic scope

Add an opt-in, session-only timing trace around the suite's Edit Mode entry work.
Measure elapsed milliseconds and call counts for:

- SeamlessUI FPS display refresh and anchor validation.
- SeamlessUI Blizzard settings extension refresh.
- Unitframes target-of-target and target-of-focus mover refreshes and previews.
- Core shared Edit Mode panel refreshes and layout callbacks.

Record the opening frame's elapsed time alongside the Lua timings so a rendering
or native layout stall is distinguishable from expensive addon callbacks. Report
nested timings as inclusive; they must not be summed as independent costs.
Keep diagnostics inactive by default, avoid per-call chat output, and preserve
normal return values and error behavior.

## In-game validation

1. Keep the current addon configuration and saved settings.
2. Arm the trace with Edit Mode closed, then open Edit Mode without selecting or
   moving a frame. Capture the report after the opening frame completes.
3. Repeat for several openings to separate first-use setup from recurring work.
4. Compare callback counts, total time, longest calls and opening frame time.
5. Use the evidence to choose a fix, then repeat the same capture to verify it.

This PR begins with the investigation plan. Timing instrumentation and an in-game
capture are pending; no performance fix or measured cause is claimed yet.
