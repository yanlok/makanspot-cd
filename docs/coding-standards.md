# Project Coding Standards

## 1. Purpose

This document defines the general coding, architecture, testing, security, and
review standards for the Flutter project. It applies to all production code,
tests, supporting scripts, and code written by developers.

The goals are to:

- keep the codebase consistent and maintainable;
- separate user interface, state, business logic, and data access;
- make changes easier to test, review, and extend;
- reduce unnecessary complexity and duplicated patterns;
- protect credentials and user data; and
- ensure that human-written and AI-generated code follow the same rules.

The keywords in this document indicate requirement strength:

- **Must / must not:** Required for correctness, security, architecture, or
  approval.
- **Should / should not:** The expected default; exceptions require a clear
  reason.
- **May:** An approved optional practice.
- **Target state:** A preferred direction that may be adopted incrementally.

## 2. Source of truth

When instructions conflict, use this order:

1. The current approved requirements and task instructions.
2. Approved architecture decisions in `docs/`.
3. This coding standard.
4. `analysis_options.yaml` and configured lint rules.
5. Effective Dart and official Flutter guidance.

Use `dart format` as the final authority for code layout. Do not manually format
code against the formatter.

## 3. Development workflow

### Before implementation

A developer or AI agent must:

1. Read the task and relevant requirements.
2. Inspect the affected source files and tests.
3. Review `pubspec.yaml`, `analysis_options.yaml`, and relevant project
   documentation when necessary.
4. Reuse existing approved patterns before introducing a new abstraction.
5. Identify the smallest coherent change that satisfies the task.
6. Avoid unrelated refactoring, package upgrades, or architecture changes.
7. Check official documentation when an API or package behavior may be
   version-sensitive.

### During implementation

- Preserve unrelated user changes.
- Keep presentation, state coordination, business rules, and data access
  separated.
- Add or update tests when observable behavior changes.
- Do not embed secrets, credentials, access tokens, private keys, or sensitive
  user information.
- Do not add a dependency when Flutter, Dart, or an existing package is
  sufficient.
- Do not suppress analyzer warnings only to make checks pass.
- A narrow lint suppression must include a comment explaining why it is safe.
- Do not refactor unrelated code as part of a focused task.

### Before completion

Run from the repository root:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

When code-generation inputs change, run the approved generation command before
these checks.

The handoff must state:

- what changed;
- which checks were run;
- whether they passed;
- which checks could not run and why; and
- any remaining risks or follow-up work.

Never claim that a check passed when it was not executed.

## 4. Architecture and separation of concerns

The project must follow its approved architecture consistently. Whether the
project uses MVC, MVVM, Clean Architecture, or another documented structure,
the following principles still apply:

- Views render state and forward user intent.
- State-management or coordination classes handle user actions and UI state.
- Business rules belong outside widgets.
- Repositories or data sources handle persistence and external services.
- Dependencies flow in one direction.
- Lower-level layers must not depend on higher-level UI layers.

Do not introduce a second architecture pattern inside the project without an
approved architecture decision.

### Views

Views may:

- render state;
- collect user input;
- forward actions;
- perform layout and animation;
- display simple presentation conditions; and
- trigger navigation through the approved router.

Views must not:

- query databases or APIs directly;
- contain business rules;
- parse backend JSON;
- perform authorization decisions; or
- manage persistent application state directly.

### Controllers, notifiers, or view models

The project’s approved state or coordination class should:

- receive user actions;
- validate user input for usability;
- coordinate repositories and services;
- expose UI-facing state; and
- map technical failures into stable UI states.

Do not create empty coordination classes for purely static screens.

### Repositories and services

Repositories and services should:

- hide external APIs, SDKs, databases, and storage details;
- expose typed application-facing methods;
- convert raw data into typed models;
- centralize mapping and error translation; and
- be replaceable with fakes in tests where practical.

Widgets must not call repositories or services directly unless the approved
architecture explicitly permits it.

## 5. Project structure

Organize code by the approved project structure and keep related files close
together. A feature-first structure is recommended for medium and large apps:

```text
lib/
  core/
    config/
    constants/
    errors/
    logging/
    network/
    router/
    theme/
    utils/

  features/
    <feature_name>/
      models/
      data/
      state/
      views/
      widgets/

  shared/
    models/
    widgets/
    extensions/

test/
  core/
  features/
  shared/
```

Only create folders that are needed. Do not generate empty layers or files only
to match a diagram.

Shared code must be genuinely reusable across multiple areas. Code used by only
one feature should remain inside that feature.

## 6. Dependency injection and state management

Use the project’s approved dependency-injection and state-management approach
consistently.

- Construct dependencies in one approved location.
- Prefer constructor injection for repositories and services.
- Avoid global mutable singletons inside feature code.
- Use reactive reads only when rebuilding is required.
- Use one-time reads for user actions that should not trigger rebuilding.
- Dispose state when it should not survive leaving its scope.
- Prevent asynchronous state updates after disposal.
- Use test overrides, fakes, or mocks for external dependencies.
- Do not mix multiple state-management styles in the same area without a
  documented reason.
- Generated state-management files must never be edited manually.

## 7. Dart naming and style

- Use `UpperCamelCase` for classes, enums, typedefs, and extensions.
- Use `lowerCamelCase` for variables, parameters, methods, providers, and
  constants.
- Use `lowercase_with_underscores.dart` for file names.
- Use lowercase directory names.
- Name classes by responsibility, such as `UserRepository`, `LoginController`,
  `LocationService`, or `ProfileScreen`.
- Avoid unexplained abbreviations.
- Avoid one-letter names except in very small conventional scopes.
- Use `final` when a value is not reassigned.
- Use `const` constructors and widgets where valid.
- Public APIs must use explicit parameter and return types.
- Avoid `dynamic` except at unavoidable serialization boundaries.
- Convert untyped data into typed objects as early as possible.
- Use sound null safety.
- Avoid force unwrap (`!`) unless the invariant is obvious and documented.
- Use braces for every control-flow body.
- Prefer clear expressions over clever or compressed code.

## 8. Imports

Order imports in groups separated by blank lines:

1. `dart:` imports.
2. `package:` imports, alphabetically.
3. Project imports, alphabetically.

Use relative imports within the same closely related directory or feature.
Use `package:` imports across top-level boundaries such as `core/`, `shared/`,
or another feature.

Do not use long relative chains such as:

```dart
import '../../../../shared/widgets/app_button.dart';
```

## 9. File, class, and method size

Numerical limits are review triggers, not automatic failures.

- Prefer source files below **300 lines of code**.
- Files above **500 lines** should be reviewed for separation by responsibility.
- Prefer methods and functions below **40 lines**.
- Methods above **60 lines** should normally be decomposed.
- Prefer one primary public responsibility per file.
- Keep widget `build` methods easy to scan and mostly declarative.
- Extract reusable, stateful, independently testable, or conceptually separate
  widget sections.
- Do not split cohesive code only to satisfy a numerical limit.
- Generated files, configuration files, and data definitions are excluded from
  these review limits.

There is no recommended maximum character count for an entire file. Character
count is not a reliable measure of maintainability.

## 10. Line length and formatting

- Prefer lines of **80 characters or fewer**.
- Treat this as a readability guideline, not a reason to fight `dart format`.
- Let the formatter decide the final layout.
- Do not align code manually with spaces.
- Do not commit unformatted Dart code.

## 11. Models and data boundaries

- Prefer immutable domain and UI-state objects.
- Use generated immutable models only when equality, copying, unions, or
  non-trivial serialization justify them.
- Keep wire-format keys inside mapping code.
- Expose idiomatic Dart field names to the rest of the app.
- Validate and convert untyped JSON at the system boundary.
- Do not pass `Map<String, dynamic>` through the application when the shape is
  stable and known.
- Represent meaningful states explicitly rather than through unrelated
  booleans.
- Represent missing information honestly with nullable fields or explicit
  states.
- Store and convert date-time values consistently.
- Be explicit about UTC and local time at system boundaries.

## 12. Asynchronous code

- Use `async` and `await` for readability unless another pattern is clearly
  better.
- Represent loading, success, empty, and error states explicitly.
- Prevent duplicate submissions while a request is in progress.
- Handle cancellation or stale results when later requests replace earlier
  ones.
- Do not update disposed state.
- Check `context.mounted` before using a `BuildContext` after an `await`.
- Apply timeouts only when the product behavior defines how timeout failures
  should be handled.
- Do not ignore returned futures unintentionally.

## 13. Error handling

- Catch only errors that can be handled, translated, enriched, or cleaned up.
- Do not use empty `catch` blocks.
- Preserve stack traces when logging or translating unexpected failures.
- Do not expose raw exception text directly to users.
- Translate technical failures into typed failures or stable application states.
- Use one consistent error/result pattern throughout the project.
- Do not use `null` to represent multiple unrelated failure conditions.
- Include useful context in logs without including sensitive data.

## 14. Flutter UI standards

- Keep `build` methods declarative and free of data access.
- Use theme tokens instead of scattered colors, text styles, radii, or spacing.
- Avoid unexplained magic numbers.
- Provide loading, empty, error, and success states for asynchronous screens.
- Use lazy builders for potentially large collections.
- Provide stable keys where identity, reordering, state preservation, or tests
  require them.
- Dispose controllers, focus nodes, subscriptions, and other owned resources.
- Avoid deeply nested widgets when extraction improves readability.
- Do not perform expensive work inside `build`.
- Keep animations purposeful and avoid blocking user interaction.
- Use the approved router and avoid duplicated route strings.

## 15. Responsive design and accessibility

- Support narrow and wide screens within the project’s target range.
- Handle safe areas, keyboard appearance, orientation, and text scaling.
- Do not rely on one fixed device size.
- Every interactive control must have a meaningful label.
- Touch targets must be sufficiently large.
- Add `Semantics` when meaning is not otherwise exposed.
- Do not communicate state using color alone.
- Maintain readable contrast.
- Ensure content remains usable under text scaling.
- Images must define sensible loading and error behavior.

## 16. Localization and user-facing text

- Do not hard-code user-facing text in new production features once
  localization infrastructure exists.
- Until localization is configured, centralize repeated strings and avoid
  patterns that make later localization difficult.
- Do not build sentences by joining translated fragments.
- Keep developer logs and technical error details separate from user-facing
  messages.

## 17. Security and privacy

- Never commit secrets, private keys, passwords, service credentials, or tokens.
- Load environment-specific values through the approved configuration system.
- Client applications must contain only credentials intended for public client
  use.
- Privileged operations must run in a trusted backend.
- Client-side validation is not an authorization boundary.
- Enforce authorization and ownership checks on the trusted backend.
- Do not log passwords, tokens, authorization headers, precise locations, or
  unnecessary personally identifiable information.
- Request permissions only when needed.
- Explain why a permission is needed.
- Handle denied and permanently denied permission states.
- Store only the minimum data required for the feature.

## 18. Networking, APIs, and persistence

- Keep API, database, and SDK-specific code outside widgets.
- Retrieve only the fields required by the use case.
- Paginate potentially unbounded collections.
- Avoid loading entire large tables or feeds into memory.
- Avoid repeated per-item requests that create N+1 query behavior.
- Define retry behavior intentionally; do not retry every failure automatically.
- Handle offline, timeout, empty, unauthorized, and server-error states.
- Use typed request and response models where practical.
- Keep cache ownership and invalidation rules explicit.
- Do not silently invent missing backend data.

## 19. Logging

- Use the project’s logging abstraction instead of `print` in production code.
- Use appropriate log levels.
- Include enough context to diagnose failures.
- Do not log sensitive data.
- Avoid excessive logs inside frequently rebuilt widgets or loops.
- Remove temporary debugging output before completion.

## 20. Dependencies and code generation

- Do not add a dependency when the SDK or an existing package is sufficient.
- Check maintenance status, platform support, license, and compatibility before
  adding a package.
- Do not upgrade Flutter, Dart, build tools, platform targets, or major packages
  during an unrelated task.
- Follow the repository policy for committing lock files.
- Generated files must not be edited manually.
- Run code generation whenever its source inputs change.
- Commit generated outputs only when required by the repository policy.

## 21. Documentation and comments

- Comments should explain intent, constraints, or non-obvious trade-offs.
- Do not narrate obvious syntax.
- Use `///` for public APIs whose purpose, lifecycle, parameters, or failure
  behavior is not obvious.
- Keep comments accurate when code changes.
- Record broad architectural decisions in `docs/` rather than oversized code
  comments.
- TODO comments must be actionable and traceable where possible.

Example:

```dart
// TODO(PROJ-123): Replace the temporary in-memory cache.
```

## 22. Testing standards

Every behavior change should have proportionate automated coverage.

### Unit tests

Use unit tests for:

- validation;
- business rules;
- mapping and serialization;
- repositories and services;
- state coordination; and
- error translation.

### Widget tests

Use widget tests for:

- important visual states;
- user interactions;
- validation messages;
- navigation triggers; and
- loading, empty, error, and success states.

### Integration tests

Use integration tests for critical user journeys and interactions between major
components. Prioritize them according to product risk and project maturity.

### General testing rules

- Tests must be deterministic and isolated.
- Use Arrange-Act-Assert.
- Do not depend on live APIs, databases, clocks, location, randomness, or other
  unstable services in unit and widget tests.
- Use fakes, mocks, fixtures, or dependency overrides.
- For a bug fix, add a regression test that fails without the fix when
  practical.
- Test important success, failure, boundary, loading, empty, and permission
  states.
- Do not optimize for coverage percentage alone.
- Name tests by observable behavior.

Example:

```dart
test('returns an empty list when no records exist', () {});

testWidgets(
  'shows a retry action when loading fails',
  (tester) async {},
);
```

Purely visual, documentation, or configuration changes may omit new tests when
existing checks provide sufficient confidence. State the reason in the handoff.

## 23. Version control and review

- Keep commits focused on one coherent purpose.
- Do not mix unrelated formatting or refactoring with feature changes.
- Use clear commit messages.
- Do not commit generated build outputs, temporary files, local configuration,
  or secrets unless explicitly required.
- Resolve analyzer warnings before review.
- Review architecture boundaries, error handling, tests, accessibility,
  security, and performance—not only formatting.
- Explain intentional deviations from this standard in the handoff or review.

## 24. Definition of done

A change is complete only when:

- approved requirements and relevant edge cases are implemented;
- project architecture and naming conventions are followed;
- affected tests are added or updated when appropriate;
- formatting, analysis, and relevant tests pass;
- generated code is current when applicable;
- loading, empty, error, and success states are handled where relevant;
- accessibility and responsive behavior are considered;
- no secrets or sensitive information are introduced;
- documentation is updated when behavior, setup, or architecture changes; and
- the handoff clearly states what changed, what was verified, and any remaining
  risk.

## 25. Incremental improvement

Apply these standards incrementally. Do not rewrite unrelated areas only to make
them match the target structure.

When touching existing code:

1. improve the affected area without expanding the task unnecessarily;
2. remove obvious duplication when it is directly related to the change;
3. replace stable untyped structures with typed models where practical;
4. move business logic and data access out of widgets;
5. add tests around the changed behavior; and
6. record larger architectural improvements as separate follow-up work.
