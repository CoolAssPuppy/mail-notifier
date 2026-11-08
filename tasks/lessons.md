# Lessons

## Never rewrite a file you have only partly read
2026-09-12: rewrote `tasks/todo.md` after reading its first 40 lines and
dropped 147 lines of project history. Caught it from `git diff --stat` and
restored from `HEAD`. Rule: prepend or edit with a targeted replacement; a
full `Write` needs the whole file in context first.

## Verify drag and drop live, not by reading the code
2026-09-12: `List` + `onMove` compiled, rendered, and did nothing, because
the row's tap gesture swallowed the mouse-down. Synthetic CGEvent drags
against the running Debug build found it; a code read never would have.

## Check the full animation path inside its card
2026-11-08: The selected theme circle could overshoot the Appearance card during
its spring return even though the open and closed states fit. Rule: inspect the
motion itself, keep enough space around its endpoint, and clip the card when
animated children must remain inside it.
