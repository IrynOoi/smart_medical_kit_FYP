// app_navigator.dart – Global navigation helpers for accessing the navigator
// from anywhere in the app, including background notification callbacks.

import 'package:flutter/material.dart';

/// Global navigator key that is set in the main MaterialApp (navigatorKey).
/// This allows us to access the navigator state from non‑widget contexts,
/// such as background notification handlers and service classes.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Navigate to the patient's Smart Reminder page using the global navigator key.
/// Returns true if the navigation was successful, false if the navigator is not yet ready.
bool openSmartReminderPage() {
  // Get the current navigator state from the global key
  final navigator = appNavigatorKey.currentState;
  // If the navigator is null (e.g., app not fully initialized or not mounted),
  // we cannot navigate – return false so the caller can retry.
  if (navigator == null) return false;

  // Push the named route '/smart-reminder' which is defined in main.dart.
  navigator.pushNamed('/smart-reminder');
  return true;
}

/// Navigate to the caregiver's Notifications page using the global navigator key.
/// Returns true if the navigation was successful, false if the navigator is not ready.
bool openCaregiverNotificationsPage() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return false;

  // Push the named route '/caregiver-notifications' defined in main.dart.
  navigator.pushNamed('/caregiver-notifications');
  return true;
}
