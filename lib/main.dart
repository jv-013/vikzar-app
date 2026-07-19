import 'app/bootstrap.dart';

/// The default entry point.
///
/// Per FLUTTER_ARCHITECTURE.md §14, this will eventually be joined by
/// `main_development.dart` / `main_staging.dart` / `main_production.dart`,
/// each calling [bootstrap] with an environment. Until Firebase
/// environment configuration exists, there is nothing to differentiate
/// between flavors, so only this single entry point is created — see
/// `app/bootstrap.dart` for the reasoning.
void main() => bootstrap();
