# AGENTS.md — schedule_app (不忘课表)

## Overview
Flutter class schedule app for Chinese high school / university students.  
Open-sourced as **buwang-schedule**. Supports timetable display, reminders,
calendar sync, and Saturday afternoon schedule variants.

## Tech Stack
- Flutter 3.x / Dart
- SQLite (local storage)
- Platform channels for native notifications & calendar

## Project Structure
```
lib/
  main.dart              # Entry point
  app.dart               # MaterialApp root
  models/                # Course, TimeSlot, AppMode, CustomReminder
  screens/               # Home, Timetable, Reminder, More
  services/              # Database, Notifications, Calendar, Logging
  theme/                 # AppTheme
  utils/                 # Constants, Extensions
```

## Build & Run
```bash
flutter pub get
flutter run            # Debug
flutter build apk      # Release APK
```

## Key Files
- `lib/utils/constants.dart` — Time slots, colors, period labels
- `lib/services/database_service.dart` — SQLite CRUD
- `lib/services/notification_service.dart` — Class reminders

## Conventions
- Follow Dart style guide (dart format)
- Use named routes defined in app.dart
- Keep business logic in services/, UI in screens/

## Known Limitations
- Notifications require platform-specific setup (Android/iOS)
- Calendar sync uses platform channels; not available on web
- Saturday afternoon slots only apply to highSchool mode

## License
MIT
