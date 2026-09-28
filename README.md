# todotxt-tng

A lightweight, modern macOS app for [todo.txt](https://github.com/todotxt/todo.txt), built with SwiftUI.

Your tasks stay in a plain `todo.txt` file. That file is the only source of truth, so
other todo.txt tools and any text editor keep working alongside the app.

## The format

This project follows the todo.txt format as defined in the
[todo.txt README](https://github.com/todotxt/todo.txt/blob/master/README.md) by Gina Trapani
and the todo.txt contributors. A copy is kept in
[`docs/todotxt-format-spec.md`](docs/todotxt-format-spec.md) as the reference.

The app follows Postel's Law: it **writes** lines that follow the spec exactly, and **reads**
lines that are less tidy (fields out of order, extra spaces or tabs). Lines you don't edit are
written back byte for byte, including blank lines, CRLF endings, a UTF-8 BOM and a missing
final newline. Unknown `key:value` tags are always kept.

### Extension tags

| Tag | Meaning |
|---|---|
| `due:YYYY-MM-DD` | Due date (Overdue / Today / Upcoming / No date views) |
| `t:YYYY-MM-DD` | Threshold: hidden until this date |
| `rec:1w`, `rec:+1m` | Recurrence (`d`, `b` business days, `w`, `m`, `y`; `+` = from due date) |
| `pri:A` | Priority kept when a task is completed |
| `cal:<id>` | Linked Calendar / Reminders item (planned) |
| `src:<uri>` | Where the task came from. `:` is stored as `;` (`https;//example.com`) because tag values can't contain colons |
| `msg:<id>` | Percent-encoded mail Message-ID |

Dates are calendar days. "Today" uses the machine's time zone. URLs typed into a task's text
(`https://…`) are left as plain text, not treated as tags.

## Building

Only the Xcode Command Line Tools are needed (Swift 6.2, macOS 26 SDK). There are no package
dependencies, so it builds offline.

```sh
swift build                    # build everything
scripts/check.sh               # run the TodoTxtCore checks (exits non-zero on failure)
scripts/bundle.sh --open       # build build/TodoTxtTNG.app, sign it ad hoc, and launch it
```

## Releases

Download the DMG from [Releases](https://github.com/Myrcurial/todotxt-tng/releases), open it,
and drag **TodoTxtTNG** to **Applications**. Builds are ad-hoc signed, not notarized, so on first
launch right-click the app and choose **Open**.

To publish a release, push a version tag. GitHub Actions runs the checks, builds the DMG and
attaches it to a new release:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

`VERSION=0.2.0 scripts/dmg.sh` builds the same DMG locally.

## Layout

| Target | Purpose |
|---|---|
| `TodoTxtCore` | Model, parser, serializer, filters, file store and file watcher. No UI. |
| `TodoTxtApp` | The SwiftUI app. |
| `TodoTxtCoreChecks` | A small self-contained test runner. `swift test` needs full Xcode, so this stands in for it for now. Its API mirrors Swift Testing (`suite` → `@Suite`, `check` → `@Test`, `expect` → `#expect`), so moving over later is mechanical. |

### Several apps editing the same file

Every change reads the current file, applies the change and writes it back atomically inside
an `NSFileCoordinator` write. If another app (or iCloud) has changed the file, the app merges
with that version instead of overwriting it. If the exact line you edited was changed
elsewhere, the edit is refused and the list reloads, so nothing is lost. Outside changes are
picked up live, including editors that save by writing a new file and renaming it.

## Roadmap

- `done.txt` archiving and saved filters
- URL scheme (`todotxt://add?text=…`) and App Intents for Shortcuts, Siri and Mail rules
- EventKit sync for `due:` tasks via `cal:`
- Menu bar quick-add and a global hotkey
- Local change history ("time machine")

## License

MIT. See [LICENSE](LICENSE).
