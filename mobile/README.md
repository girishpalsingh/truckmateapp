# TruckMate App

TruckMate is a mobile application for trucking management, built with Flutter. It helps small carriers manage trips, loads, expenses, and documents with offline-first capabilities.

## Architecture Overview

This project follows a **Feature-first / Layered Architecture** combined with **Riverpod** for state management.

### Key Technologies
- **Flutter**: UI Framework
- **Riverpod**: State Management (`flutter_riverpod`, `riverpod_annotation`)
- **Supabase**: Backend (Auth, Database, Storage, Edge Functions)
- **PowerSync**: Offline-first data synchronization (Local SQLite <-> Supabase)
- **Localization**: Standard `flutter_localizations` with ARB files

### Layers
1.  **Presentation (`lib/presentation`)**: Contains the UI logic.
    -   `screens/`: Individual pages/views of the application.
    -   `widgets/`: Reusable UI components.
    -   `providers/`: Riverpod providers for managing UI state.
    -   `themes/`: App theming and styling.
2.  **Services (`lib/services`)**: Business logic and specialized services.
    -   Encapsulates logic like Authentication, Trip Management, Expense Tracking, etc.
    -   Examples: `AuthService`, `TripService`, `PowerSyncService`.
3.  **Data/Domain (`lib/data`)**: Data models and repositories.
    -   `models/`: Dart data classes (often using `freezed`).
    -   `repositories/`: Abstract and concrete implementations for data access.

## Project Structure

```text
lib/
├── config/         # App configuration (Environment, constants)
├── core/           # Core utilities and shared logic
├── data/           # Data layer (Models, Repositories, Datasources)
├── l10n/           # Localization files (ARB)
├── presentation/   # UI Layer
│   ├── providers/  # State management providers
│   ├── screens/    # App screens (Views)
│   ├── themes/     # App themes
│   └── widgets/    # Reusable widgets
├── services/       # Application services (Business Logic)
└── main.dart       # Application entry point
```

## View Paths & Routes

The application uses named routes defined in `main.dart`.

| Route Path | Screen Class | Description |
| :--- | :--- | :--- |
| `/` | `WelcomeScreen` | Initial landing / splash screen. |
| `/login` | `LoginScreen` | User authentication screen. |
| `/dashboard` | `DashboardScreen` | Main dashboard (Loads, KPIs). |
| `/trip/new` | `NewTripScreen` | Create a new trip. |
| `/trip/active` | `ActiveTripScreen` | View details of current active trip. |
| `/trips` | `TripListScreen` | History/List of all trips. |
| `/scan` | `DocumentScannerScreen` | Interface for scanning physical documents. |
| `/expense` | `ExpenseScreen` | Log and manage expenses. |
| `/documents` | `PendingDocumentsScreen` | Review and upload pending documents. |

**Other Screens (Navigated via actions):**
-   `DocumentViewerScreen`: View captured/uploaded documents.
-   `NotificationScreen`: View app notifications.
-   `RateConAnalysisScreen`: Analyze Rate Confirmation details.
-   `RateConClausesScreen`: View specific clauses from a Rate Con.
-   `RateConReviewScreen`: Review parsed Rate Con data.

## Getting Started

1.  **Setup Environment**: Ensure you have Flutter installed.
2.  **Dependencies**: Run `flutter pub get` to install dependencies.
3.  **Configuration**: Verify `lib/config/app_config.dart` exists and has valid Supabase/PowerSync credentials.
4.  **Run**: `flutter run`

## Backend Integration
-   **Supabase**: Handles Auth and is the source of truth for data.
-   **PowerSync**: Syncs data to a local SQLite database (`truckmate.db`) for offline access.
-   **Edge Functions**: Used for complex backend logic (e.g., OCR, PDF generation).
