# CLAUDE.md - Azure DevOps Mobile App

## Project Overview

Unofficial Azure DevOps mobile client built with Flutter/Dart. Manages pipelines, pull requests, work items, commits, boards, sprints, and repositories.

- **Package:** `azure_devops`
- **Dart SDK:** `>=3.9.0 <4.0.0`
- **Flutter SDK:** `>=3.38.0`
- **Platforms:** iOS, Android
- **Lints:** `purple_lints` (custom package)

## Commands

```bash
flutter run                    # Run app (debug)
flutter build apk             # Build Android
flutter build ios              # Build iOS
flutter test                   # Run all tests
dart analyze                   # Static analysis
flutter test test/pipelines_test.dart  # Single test file
```

Compile-time env vars via `--dart-define`:
- `FIREBASE` - enable Firebase analytics
- `SENTRY_DNS` - Sentry DSN
- `MSAL_CLIENT_ID`, `MSAL_REDIRECT_URI` - Microsoft auth
- `REVENUE_CAT_API_KEY_IOS`, `REVENUE_CAT_API_KEY_ANDROID` - RevenueCat
- `ADMOB_INTERSTITIAL_ADID_ANDROID`, `ADMOB_INTERSTITIAL_ADID_IOS` - AdMob interstitial
- `ADMOB_NATIVE_ADID_ANDROID`, `ADMOB_NATIVE_ADID_IOS` - AdMob native

## Architecture

### Directory Structure

```
lib/
  main.dart              # Entry point: Firebase, Sentry, theme, ads init
  src/
    app.dart             # Root widget, InheritedWidget service tree
    bindings/            # Flutter engine binding overrides
    extensions/          # Extension methods on types (15 files)
    mixins/              # Cross-cutting concerns (6 files)
    models/              # Data models with fromJson factories (40+ files)
    router/              # Named route definitions and navigation helpers
    screens/             # Feature screens (28 directories)
    services/            # Business logic services (10 files)
    theme/               # AppTheme, color schemes, DevOpsIcons
    utils/               # Utility functions
    widgets/             # Reusable UI components (32 files)
test/
  api_service_mock.dart  # Shared mock implementations
  *_test.dart            # Widget tests per screen
```

### Service Injection (InheritedWidget)

No third-party state management. Services are injected via InheritedWidget wrappers nested in `lib/src/app.dart`:

```
PurpleTheme
  AdsServiceWidget          <- context.ads
    PurchaseServiceWidget    <- context.purchase
      AzureApiServiceWidget  <- context.api
        StorageServiceWidget <- context.storage
          MaterialApp
```

Access via context extensions (defined in `lib/src/extensions/context_extension.dart`):

```dart
context.api       // AzureApiService
context.storage   // StorageService
context.ads       // AdsService
context.purchase  // PurchaseService
```

Each service: abstract interface + singleton implementation + InheritedWidget wrapper.

### Services

| Service | File | Purpose |
|---------|------|---------|
| `AzureApiService` | `services/azure_api_service.dart` | Main API client (~2600 lines, 50+ methods). Abstract + `AzureApiServiceImpl` singleton. |
| `StorageService` | `services/storage_service.dart` | SharedPreferences persistence. Organization, projects, tokens, filters. |
| `MsalService` | `services/msal_service.dart` | Microsoft MSAL authentication (JWT). Singleton. |
| `AdsService` | `services/ads_service.dart` | Google AdMob + Amazon ads. |
| `PurchaseService` | `services/purchase_service.dart` | RevenueCat in-app subscriptions. |
| `FiltersService` | `services/filters_service.dart` | Filter persistence per organization/area. Instantiated per controller. |
| `OverlayService` | `services/overlay_service.dart` | Static methods for confirm dialogs, snackbars, bottom sheets. |

## Screen Pattern (Critical)

Every screen follows a 5-file `library`/`part` pattern:

```
screens/<feature>/
  base_<feature>.dart          # library declaration, imports, public Page widget
  controller_<feature>.dart    # part of; private _Controller with business logic
  screen_<feature>.dart        # part of; private _Screen widget (builds UI)
  components_<feature>.dart    # part of; private helper widgets (can be empty)
  parameters_<feature>.dart    # part of; private _Parameters class for layout
```

**Example** (`screens/pipelines/base_pipelines.dart`):

```dart
library pipelines;
part 'controller_pipelines.dart';
part 'screen_pipelines.dart';
part 'components_pipelines.dart';
part 'parameters_pipelines.dart';

class PipelinesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = AppRouter.getPipelinesArgs(context);
    return AppBasePage(
      initState: () => _PipelinesController._(context.api, context.storage, args, context.ads),
      smartphone: (ctrl) => _PipelinesScreen(ctrl, _smartphoneParameters),
      tablet: (ctrl) => _PipelinesScreen(ctrl, _tabletParameters),
    );
  }
}
```

**Rules:**
- `base_*.dart` is the only public file; declares `library` and all `part` directives
- All other files use `part of <library>;` -- they share the same private namespace
- The controller is private (`_Controller`) and instantiated in the base page
- `AppBasePage<T>` provides smartphone/tablet layout switching (breakpoint at 600px)
- Controllers receive services via constructor, NOT by accessing context

## State Management

Controllers use `ValueNotifier<ApiResponse<T>?>` for reactive state:

```dart
final pipelines = ValueNotifier<ApiResponse<List<Pipeline>?>?>(null);
```

**State interpretation:**
- `null` = loading (shows spinner)
- `ApiResponse(isError: true)` = error (shows error page with retry)
- `ApiResponse(isError: false, data: [])` = empty (shows empty message)
- `ApiResponse(isError: false, data: [...])` = success (renders content)

**ApiResponse** (defined at bottom of `azure_api_service.dart`, line ~2598):

```dart
class ApiResponse<T extends Object?> {
  ApiResponse.ok(this.data);              // success
  ApiResponse.error(this.errorResponse);  // failure with HTTP Response
  final bool isError;
  final T? data;
  final Response? errorResponse;
}
```

`AppPage<T>` widget (`widgets/app_page.dart`) renders the appropriate state automatically using `ValueListenableBuilder` + pull-to-refresh.

## API Layer

All API methods are on `AzureApiService` (abstract) / `AzureApiServiceImpl`.

- **HTTP client:** `SentryHttpClient` (wraps `package:http`)
- **Auth:** JWT (MSAL Bearer token) or PAT (Basic auth), auto-detected by token format (`ey...` with 3 segments = JWT)
- **Token refresh:** On 203 or 302 response, calls `MsalService().loginSilently()` and retries
- **Base URL:** `https://dev.azure.com/{organization}`
- **API version:** `api-version=7.0`
- **Logging:** All calls logged via `_logApiCall`, errors reported to Sentry with 2-second debounce

## Routing

Defined in `lib/src/router/router.dart`. Static named routes with typed record args:

```dart
// Typedefs
typedef PipelinesArgs = ({Project? project, int? definition, SavedShortcut? shortcut});
typedef WorkItemDetailArgs = ({String project, int id});

// Navigation
AppRouter.goToPipelineDetail(id: 123, project: 'MyProject');
AppRouter.goToWorkItemDetail(project: 'MyProject', id: 456);
AppRouter.pop();

// Arg retrieval (in base page)
final args = AppRouter.getPipelinesArgs(context);
```

## Mixins

| Mixin | File | Purpose |
|-------|------|---------|
| `FilterMixin` | `mixins/filter_mixin.dart` | Project/user filter state, `getSortedUsers()`, `searchUser()`, homonym detection |
| `ApiErrorHelper` | `mixins/api_error_mixin.dart` | Parse error messages/types from HTTP responses, work item error detection |
| `AdsMixin` | `mixins/ads_mixin.dart` | Native/interstitial ad management, show ads every 5 items in lists |
| `AppLogger` | `mixins/logger_mixin.dart` | `logDebug` (console), `logInfo`/`logError` (Sentry), `logAnalytics` (Firebase with `az_` prefix) |
| `ShareMixin` | `mixins/share_mixin.dart` | Share URLs via system share sheet |
| `PullRequestHelper` | `mixins/pull_request_mixin.dart` | PR text processing, work item link replacement, mention replacement |

## Extensions

| Extension | File | Key Methods |
|-----------|------|-------------|
| `PurpleContext` | `context_extension.dart` | `textTheme`, `colorScheme`, `height`, `width`, `api`, `storage`, `ads`, `purchase` |
| `ResponseExt` | `reponse_extension.dart` | `isError` - checks status NOT in [200, 201, 204, 206] |
| `DateTimeExt` | `datetime_extension.dart` | `toSimpleDate()`, `minutesAgo`, `isToday()`, `timeDifference()` |
| `StringExt` | `string_extension.dart` | `formatted`, `titleCase` |
| `NumExt` | `num_extension.dart` | `formatted`, `toCurrency()`, `toPercentage()` |
| `DurationExt` | `duration_extension.dart` | `toMinutes` |
| `PipelineExt` | `pipeline_extension.dart` | Status-based icon and ordering |
| `PullRequestExt` | `pull_request_extension.dart` | Branch extraction, vote descriptions, status icons |
| `CommitExt` | `commit_extension.dart` | Extract project/repo from URLs |
| Domain-specific | `approval_extension.dart`, `area_or_iteration_extension.dart`, `work_item_*_extension.dart` | Formatting and display helpers |

## Testing

Widget tests with mock service InheritedWidgets:

```dart
final app = MaterialApp(
  theme: mockTheme,
  home: StorageServiceWidget(
    storage: StorageServiceMock(),
    child: AdsServiceWidget(
      ads: AdsServiceMock(),
      child: AzureApiServiceWidget(
        api: AzureApiServiceMock(),
        child: PipelinesPage(),
      ),
    ),
  ),
);
await tester.pumpWidget(app);
```

- Mocks in `test/api_service_mock.dart` (implement abstract service interfaces)
- `mockTheme` provides consistent theme data for tests
- Golden tests supported via `test/goldens/` directory

## Common Pitfalls

1. **Part files share private scope.** All 5 screen files share one `library`. A private `_Controller` in `controller_*.dart` is visible to `screen_*.dart` and `components_*.dart`. Do NOT import these files separately.

2. **Services are singletons.** `AzureApiServiceImpl()`, `StorageServiceCore()`, `MsalService()`, `AdsServiceImpl()` use factory constructors returning static instances.

3. **`context.api` only works below the InheritedWidget.** The nesting order in `app.dart` matters. New services must be wired into the InheritedWidget chain.

4. **Controllers do NOT hold BuildContext.** They receive services via constructor. Navigation uses static `AppRouter` methods.

5. **`ApiResponse` lives in `azure_api_service.dart`**, not in a separate model file (bottom of the file, line ~2598).

6. **Token type is auto-detected**, not configured. JWT vs PAT inferred from token format at login.

7. **`components_*.dart` can be empty** (just `part of <library>;`). Not every screen needs extra components.

8. **`analysis_options.yaml` suppresses `library_private_types_in_public_api`** because the architecture deliberately uses private types across part files.

9. **`FiltersService` is per-controller** (not singleton), receiving `storage` and `organization` to namespace filters.

10. **Env vars are compile-time constants** via `String.fromEnvironment` / `bool.fromEnvironment`. They require `--dart-define` at build time, not runtime env vars.
