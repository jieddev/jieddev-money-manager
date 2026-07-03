# SQLite Implementation

This app now uses SQLite as the source of truth for money data instead of keeping balance and transactions only in memory.

## What was added

- A repository layer in `lib/data/money_manager_repository.dart` that owns all SQLite access.
- A `transactions` table to store each money change with amount, category, sign, and timestamp.
- A `categories` table to store the default and custom categories used by the app.
- App startup loading so the home screen renders from persisted data.
- Write-through updates so new transactions are saved to SQLite before the UI and widget refresh.
- A seven-day balance line chart above transaction history, derived from the stored transaction timestamps.
- A test fake so the Flutter widget test can run without a real database.

## Data model

The database has two tables:

### `categories`

- `id` integer primary key
- `name` unique text field

### `transactions`

- `id` integer primary key
- `amount` integer amount entered by the user
- `category` category label
- `is_addition` stored as `1` for additions and `0` for subtractions
- `created_at` UTC ISO-8601 timestamp

## App flow

1. `main()` creates `SqliteMoneyManagerRepository`.
2. `MoneyManagerHomePage` loads a snapshot from SQLite in `initState()`.
3. The snapshot updates the balance, transaction list, and categories shown in the UI.
4. The home screen also derives a seven-day balance series from the stored transaction timestamps and renders it as a line chart above the history list.
5. When the user submits a transaction, the app writes it to SQLite.
6. After the write completes, the app reloads the snapshot and refreshes the home widget with the new balance.

## Widget sync

The Android widget still reads the balance from `HomeWidgetPlugin.getData(context)`, but that balance is now refreshed from the SQLite-backed app state instead of from an in-memory value.

## Validation

- Added a repository-backed widget test using a fake implementation.
- The test covers loading persisted state and updating the balance after a new transaction.

## Follow-up work

- Add stronger repository tests against a real SQLite-backed test database.
- Persist more metadata if the app later needs reporting or filtering.
- Consider exposing transaction totals by category if the UI expands.