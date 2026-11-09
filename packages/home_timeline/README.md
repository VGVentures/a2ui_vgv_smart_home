# home_timeline

The demo's timeline, as pure Dart: the scenario clock and the activity feed
the model ranks a screen by.

| Piece | What it does |
| --- | --- |
| `ScenarioClock` | A clock that starts at a fixed moment and only moves when something moves it. |
| `wall_time.dart` | Naive local times (`2026-10-10T16:30:00`), `HH:mm` and `5:30 PM` helpers. |
| `ActivityFeed` | What just happened (`recent`) and what comes next (`next`) for one user, derived from the data at the clock's time. |
| `FeedSource` | What the feed reads. The backend's mock database implements it. |
| `feed_rules.json` | Every moment the feed can show, and what it says. |

## The feed is JSON

Nothing is stored. Each time the feed is asked, `ActivityFeed` reads the facts
out of the data (an order's times, a trip's stops, a plan step) and
`lib/src/feed_rules.json` turns them into moments. To change what the feed says
or flags, edit the JSON. To give it a new kind of moment, add a source in
`ActivityFeed._facts` and its rules in the JSON.

```json
{
  "source": "bakeryOrder",
  "at": "eta",
  "when": "atTheDoor",
  "kind": "bakery",
  "summary": ["The {item} is delivered: the courier is at the front door. ", "..."],
  "urgent": true
}
```

| Key | Meaning |
| --- | --- |
| `source` | Which facts the rule reads: `oven`, `planStep`, `todoList`, `bakeryOrder`, `trip`, `calendarEvent`, `doorbell`, `change`, `inboxItem`. One moment per fact set. |
| `at` | The fact holding when it happens. No such fact, no moment. |
| `when` | A true/false fact the rule needs, or `!fact` for its opposite. |
| `kind` | `oven`, `plan`, `bakery`, `trip`, `calendar`, `doorbell`, `change`, `inbox` or `todo`. |
| `summary` | The text, with `{fact}` slots. Times print as `5:30 PM`. A list is joined, to keep long lines readable. |
| `subject` | Who it concerns: a user id or `{fact}`. Defaults to `household`. |
| `by`, `deviceId`, `stepId`, `listId`, `tripId`, `itinerary` | Extra fields the screen can point at. |
| `urgent` | Something to act on right now. |
| `pastOnly` | Only counts once the clock has reached it. |
| `alwaysNext` | Listed as coming up however far off it is. |

`recentMinutes` and `nextMinutes` at the top set the two windows.

## Deploying

The AOT server cannot find a package file, so deploys copy `feed_rules.json`
to `assets/feed_rules.json`, where `FeedRules.bundled` looks next.

## Check

```bash
dart format lib test
dart analyze --fatal-infos lib test
very_good dart test --coverage --min-coverage 95
```
