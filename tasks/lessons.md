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
