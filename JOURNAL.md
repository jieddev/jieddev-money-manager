NOTE: The Journal was created late

## Add a pagination for transaction history

- Updated `home_page.dart` to limit transaction history list
  - Defined `_transactionsPageSize` and set its value to 10
  - Added a `_loadMoreTransactions` function that can load more transaction history in the list by setting the state of the `_visibleTransactionCount`
  - Added a `_visibleTransactions` list getter to expose only the `_visibleTransactionCount` from the full `_transactions` list as an immutable-length list

## Implement Optional category and tags

- Updated `displayText` method in `money_manager_repository.dart` to display text appropriately when no category or description is provided.

- Updated `widget_test.dart` test to test if the app can support optional category and optional tag.


PROBLEM/Performance: I realized that the app loads all the transaction history from the database which might cause a performance issue when the data gets bigger.

## Minimal refactor of codebase

- run `/init` in Claude CLI.
- Prompted Claude to refactor the codebase and follow SOLID Principle.

- Add notes in `CLAUDE.md` to let Claude know that I want it to use easy to understand code implementation without using complex over-engineered code.

## Implement undo feature - Commit 0afc2c6af10a51f55a2

- The undo feature aims to undo latest transaction entry via the snackbar button.

- Added `deleteTransaction` function inside `money_manager_repository.dart` that gets in the database, find the transaction with the target id and deletes it.

- Modified `home_page.dart` function to show snackbar with 'Undo' button after adding a new transaction entry.
  - Created a private `_undoTransaction` that takes `TransactionRecord transaction` parameter that calls `widget.repository.deleteTransaction` method to delete record from the database and reload snapshot of transactions.

- Modified `widget_test.dart` to test undo feature.


## Update home widget to be clickable - Commit 64cdab

- Modified `moneyManagerWidgetProvider.kt` to import `HomeWidgetLaunchIntent` and call `setOnClickPendingIntent`

ERROR: "A failure occurred while executing org.jetbrains.kotlin.compilerRunner.btapi.BuildToolsApiCompilationWork Compilation error. See log for more details"

REASON: `widget_root` is referenced in the Kotlin code but never defined in the layout.

FIX: Add `android:id="@+id/widget_root` inside `money_manager_widget.xml` to reference it.


## Implement "Enter initial balance" feature

- Created `enter_balance_dialog.dart` that accepts currentBalance and displays a dialog to input current balance.
- Modified `home_page.dart` to add "Set Balance" button that calls `_openEnterBalanceDialog`.
  - `_openEnterBalanceDialog` that shows the dialog, checks if the difference of new balance and current balance is equal to 0 or not, if not then it will add the transaction to the repository and reload snapshot and display a snackbar message.

## Add Device Preview
- Add `device_preview` dependency and import it at `main.dart`.
- Wrapped the app with `DevicePreview`.

## Add Budget Breakdown Display on Home Page

- Updated `home_page` and created a layout for the budget breakdown card

## Savings Transaction Page to add or deduct savings balance

- Created a `savings_transaction_page`

## Created a reusable transaction envelope for each budget category

  - Reusable page for each category transaction
  - Redesign transaction envelope
  - Display Spare balance