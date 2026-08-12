# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Jieddev Money Manager is an offline-first personal finance tracker built with Flutter. Its core differentiator is an Android home-screen widget that shows the current balance and recent transactions directly on the phone's home screen. SQLite (via `sqflite`) is the source of truth for all balance and transaction data.

## Commands

```bash
flutter pub get                          # install dependencies
flutter run                              # run the app
flutter test                             # run all tests
flutter test test/widget_test.dart       # run the (currently only) test file
flutter test --plain-name "<test name>"  # run a single named test
flutter analyze                          # static analysis (stock flutter_lints, no custom overrides)
```

## Architecture

`lib/` has three files:

- `lib/main.dart` — composition root. Constructs a `SqliteMoneyManagerRepository` and injects it into `MyApp` → `MoneyManagerHomePage`.
- `lib/data/money_manager_repository.dart` — the entire data layer.
- `lib/features/home/home_page.dart` — the entire UI: home screen, balance chart, and the transaction entry page.

**Repository pattern.** `MoneyManagerRepository` is an abstract interface (`loadSnapshot`, `loadMoreTransactions`, `addTransaction`) implemented by `SqliteMoneyManagerRepository`. It's constructor-injected into the widget tree rather than looked up globally, which is also how tests substitute a fake. `test/widget_test.dart` defines `FakeMoneyManagerRepository`, an in-memory implementation — follow that pattern for new tests instead of hitting a real database.

**SQLite schema.** Two tables: `categories` (`id`, unique `name`) and `transactions` (`id`, `amount`, `category`, `description`, `is_addition`, `created_at` as a UTC ISO-8601 string). The `_db` getter in `money_manager_repository.dart` opens the database with a versioned `onCreate`/`onUpgrade` (currently schema version 2). When changing the schema, add a new `onUpgrade` branch rather than editing `_createSchema` in place, so existing installs migrate correctly.

**Pagination.** `loadSnapshot(transactionLimit:)` returns only the most recent page of transactions. `loadMoreTransactions(beforeTransaction:, transactionLimit:)` keyset-paginates on `(created_at, id)` for older pages. This exists specifically to avoid loading the full transaction history into memory (see `JOURNAL.md` for the performance problem that motivated it) — don't reintroduce an unbounded "load everything" query.

**Home widget sync.** After every snapshot load or mutation, `home_page.dart` pushes state to the native widget via `HomeWidget.saveWidgetData` and `HomeWidget.updateWidget(name: 'MoneyManagerWidgetProvider')`. The native Android side lives outside `lib/`: `android/app/src/main/kotlin/MoneyManagerWidgetProvider.kt`, `android/app/src/main/res/layout/money_manager_widget.xml`, `android/app/src/main/res/xml/money_manager_widget_info.xml`, and a `<receiver>` entry in `android/app/src/main/AndroidManifest.xml`. Changing what data the widget displays requires updating both the Flutter side and the Kotlin/XML side.

**Currency.** Amounts are stored and passed around as `int` (no explicit smallest-unit convention documented). Display formatting (with a ₱ prefix) happens in `_formatCurrency`/`_formatAxisCurrency` in `home_page.dart`.

## Project docs

These already capture project history — consult them instead of re-deriving the same context:

- `SQLITE_IMPLEMENTATION.md` — data model and app data flow.
- `HOME_WIDGET_SETUP.md` — how the Android home widget was wired up, step by step.
- `JOURNAL.md` — dev log of past changes and known issues (e.g. the transaction-history performance problem that led to pagination).
- `milestone.md` — rough roadmap of upcoming work.

## Project Philosophy
- Separate classes and functions into separate file if possible.
- Ensure SOLID Principle.

## NOTES
- Use code that is easy to understand without using complex over-engineered code.