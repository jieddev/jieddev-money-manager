NOTE: The Journal was created late

## Add a pagination for transaction history

- Updated `home_page.dart` to limit transaction history list
  - Defined `_transactionsPageSize` and set its value to 10
  - Added a `_loadMoreTransactions` function that can load more transaction history in the list by setting the state of the `_visibleTransactionCount`
  - Added a `_visibleTransactions` list getter to expose only the `_visibleTransactionCount` from the full `_transactions` list as an immutable-length list

## Implement Optional category and tags

- Updated `displayText` method in `money_manager_repository.dart` to display text appropriately when no category or description is provided.

- Updated `widget_test.dart` test to test if the app can support optional category and optional tag.