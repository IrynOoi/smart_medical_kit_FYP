// lib/services/app_navigator.dart
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

bool openSmartReminderPage() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return false;

  navigator.pushNamed('/smart-reminder');
  return true;
}

bool openCaregiverNotificationsPage() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return false;

  navigator.pushNamed('/caregiver-notifications');
  return true;
}
