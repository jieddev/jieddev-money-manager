# Home Widget Setup Steps

## 1. Add the dependency
Added `home_widget` to `pubspec.yaml` so the app can save balance data and trigger widget refreshes.

## 2. Update Flutter app logic
In `lib/main.dart`:
- initialized Flutter bindings before `runApp`
- saved the balance with `HomeWidget.saveWidgetData<int>('balance', _balance)`
- refreshed the widget with `HomeWidget.updateWidget(name: 'MoneyManagerWidgetProvider')`

## 3. Create the widget layout
Added `android/app/src/main/res/layout/money_manager_widget.xml` to define the Android home screen widget UI.

## 4. Create the widget provider
Added `MoneyManagerWidgetProvider.kt` to:
- read the saved `balance` value from shared storage
- update the widget’s text view with the current balance

## 5. Add the widget config
Added `android/app/src/main/res/xml/money_manager_widget_info.xml` to define widget size and layout settings.

## 6. Register the widget in the manifest
Added a `<receiver>` entry in `android/app/src/main/AndroidManifest.xml` so Android can discover the widget.

## 7. Fix the refresh target
Updated `HomeWidget.updateWidget(...)` so the Flutter app refreshes the correct Android widget provider.

## 8. Result
The app now saves balance changes and the home widget reads and displays the updated value.