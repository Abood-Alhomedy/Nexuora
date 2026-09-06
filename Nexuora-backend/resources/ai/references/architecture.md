# Flutter Viz Unified Architecture (Dart Backend & Flutter Frontend)

## Canonical Project Structure

flutterviz/
├── backend/                  # Dart Backend Project (Dart Frog / Shelf)
│   ├── routes/               # API Endpoint Routes
│   │   └── api/
│   │       └── [entity]/
│   │           ├── index.dart
│   │           └── [id].dart
│   ├── lib/
│   │   ├── models/           # Server-side Models & DTOs
│   │   ├── repositories/     # Data Persistence Layer
│   │   └── services/         # Server Logic
│   └── pubspec.yaml
│
├── lib/                      # Flutter Frontend App
│   ├── models/               # Shared Data Models (matching backend)
│   ├── services/
│   │   └── api_service.dart  # Generated HTTP Client binding backend routes
│   └── screens/              # Flutter UI Screens
│
└── pubspec.yaml              # Flutter Dependencies
