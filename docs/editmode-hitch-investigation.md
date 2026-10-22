# Edit Mode hitch investigation

Opening Edit Mode causes a visible hitch and FPS drop with SeamlessUI enabled.
Disabling its options has not resolved it. Focus and target-of-target changes are
suspected, but no timing evidence establishes the cause yet.

## Diagnostic scope

An opt-in, session-only timing trace measures the suite's Edit Mode entry work.
Measure elapsed milliseconds and call counts for:

- SeamlessUI FPS display refresh and anchor validation.
- SeamlessUI Blizzard settings extension refresh.
- Unitframes target-of-target and target-of-focus mover refreshes and previews.
- Core shared Edit Mode panel refreshes and layout callbacks.

The first observed active frame and worst frame interval are reported alongside
Lua timings. These intervals include native work, rendering and other addons;
they cannot attribute a stall to one addon. Nested timings are inclusive and must
not be summed as independent costs. Instrumentation adds measurement overhead.

The trace does not change saved settings or profiling CVars. It temporarily wraps
addon-owned methods and removes the wrappers after the capture, cancellation, a
60-second timeout or a traced error. The report prints the 15 highest total Lua
timings, including call counts and the longest call. Diagnostics are inactive by
default. No native frame methods or vendored library files are modified.

## In-game validation

1. Keep the current addon configuration and saved settings.
2. With Edit Mode closed and out of combat, run `/seamless trace`, then open Edit
   Mode without selecting or moving a frame. A chat report follows automatically
   after roughly 0.75 seconds of observed active frame intervals.
3. Repeat for several openings to separate first-use setup from recurring work.
4. Compare callback counts, total time, longest calls and opening frame time.
5. Use the evidence to choose a fix, then repeat the same capture to verify it.

Use `/seamless trace report` to repeat the last report or `/seamless trace off` to
cancel. Reports last until reload. Instrumentation covers the loaded suite Ace
modules' refresh/apply methods, Core refresh methods, shared anchor validation,
SeamlessUI anchor lists, LibEditMode settings refreshes, and ToT mover/preview work.
It records calls while the native manager reports Edit Mode active; it does not
measure native methods or the complete native entry event dispatch.

Run `lua src/tests/editmode-trace.lua` for return-value preservation, timing and
counts, inherited-method restoration, duplicate targets, cancellation, timeout,
combat/already-open guards, error propagation and cleanup.

The first in-game capture and resulting repair are recorded below. A follow-up
capture is needed to measure the remaining cost in the client.

## First capture and scoped repair

The reported capture had a 713 ms worst frame. `LegacyLayout.Refresh` ran 88 times
and took 605.54 ms inclusive; `HealthColor.Refresh` also ran 88 times (58.51 ms,
included in the layout refresh). ToT preview work took 0.44 ms across two calls.

Native unit-frame hooks were calling the full legacy layout refresh, rebuilding
all unit frames and recoloring all health bars for each individual update. They
now repair only the frame that changed, including its health color. Repairs remain
synchronous. Explicit settings changes and roster/lifecycle events retain full
refreshes. Combo points are only repositioned when the target frame is repaired.

The legacy harness simulates 88 native mana-bar updates and verifies that each
repairs only its player-frame owner, with no full frame scans, global recolors or
unrelated combo-point writes. It also checks focus-only repairs and ignored
unrelated/secret owners. Repeat the in-game capture to measure the improvement;
the remaining cost has not been measured in the client yet.

## Second capture and measurement gap

After the scoped repair, the reported worst frame fell from 713 ms to 175 ms.
The same 88 legacy refreshes took 34.66 ms instead of 605.54 ms, and frame-local
health color refreshes took 3.31 ms. ToT previews still took only 0.45 ms.

This leaves a stall that the original method list does not explain. Legacy atlas
hooks can call the artwork painter directly, outside `Refresh`, and those calls
were not timed. The existing painter is now an instrumentable `Paint` method;
its algorithm and health-color logic are unchanged. The trace includes `Paint`
and a covered-Lua total that counts nested calls once across the entire capture.
That total must not be subtracted directly from the worst frame, which is only
one frame interval within the capture.

Capture again after pulling this update. Compare two openings to distinguish
first-use work from recurring costs. No additional performance fix is inferred
from the unexplained part of the frame interval.

## Warm capture and redundant anchor writes

The expanded trace measured 42.59 ms of covered Lua with a 140 ms worst frame.
A second opening without reload measured 42.34 ms with a 120 ms worst frame;
both performed 88 layout repairs. This establishes recurring work, while the
remaining frame interval is still not fully attributed.

Each repair cleared and reapplied fixed anchors even when their definitions had
not changed. The PvP icon also received an intermediate anchor before its final
legacy anchor in every repair. Fixed anchors now cache only the last successful
addon-authored write and native point/all-points/parent setters invalidate it.
No live anchor getters or native setter arguments are read. Nested setter activity
leaves the entry uncached, and combat-skipped writes never populate the cache.
The PvP icon receives its final anchor directly.

The legacy harness verifies that 88 stable native mana updates perform zero
anchor writes, native setter invalidations still force synchronous repair, and
nested setters and combat guards remain correct. Dimensions and other layout
work still run. Repeat the capture to measure the client impact; redundant
anchor writes are verified, but their contribution to the remaining hitch is
not yet measured.
