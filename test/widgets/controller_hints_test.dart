import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/services/gamepad_service.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/widgets/controller_hints.dart';
import 'package:slang_flutter/slang_flutter.dart';

import '../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
    GamepadService.debugClearTabNavigationHandlers();
  });

  testWidgets('browse hints are visible when setting is on and source is gamepad', (tester) async {
    final settings = await SettingsService.getInstance();
    settings.write(SettingsService.showControllerButtonHints, true);

    await tester.pumpWidget(
      TranslationProvider(
        child: InputModeTracker(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  InputModeTracker.reportGamepadInput();
                  return ValueListenableBuilder<InputSource>(
                    valueListenable: InputModeTracker.sourceListenable,
                    builder: (context, source, _) {
                      return const BrowseControllerHints(showTabs: false);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(t.controllerHints.select), findsOneWidget);
    expect(find.text(t.controllerHints.back), findsOneWidget);
    expect(find.text(t.controllerHints.options), findsOneWidget);
  });

  testWidgets('browse hints hide when input source is not gamepad', (tester) async {
    final settings = await SettingsService.getInstance();
    settings.write(SettingsService.showControllerButtonHints, true);

    await tester.pumpWidget(
      TranslationProvider(
        child: InputModeTracker(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Don't call reportGamepadInput to keep source as pointer
                  return ValueListenableBuilder<InputSource>(
                    valueListenable: InputModeTracker.sourceListenable,
                    builder: (context, source, _) {
                      if (source == InputSource.gamepad) {
                        return const BrowseControllerHints(showTabs: false);
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(t.controllerHints.select), findsNothing);
  });

  testWidgets('browse hints show tab buttons when showTabs is true', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const BrowseControllerHints(showTabs: true);
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(t.controllerHints.previousTab), findsOneWidget);
    expect(find.text(t.controllerHints.nextTab), findsOneWidget);
  });

  testWidgets('browse hints hide tab buttons when showTabs is false', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const BrowseControllerHints(showTabs: false);
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(t.controllerHints.previousTab), findsNothing);
    expect(find.text(t.controllerHints.nextTab), findsNothing);
  });

  testWidgets('player hints display all button hints', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const PlayerControllerHints();
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(t.controllerHints.select), findsOneWidget);
    expect(find.text(t.controllerHints.back), findsOneWidget);
    expect(find.text(t.controllerHints.playPause), findsOneWidget);
    expect(find.text(t.controllerHints.audioSubs), findsOneWidget);
    expect(find.text(t.controllerHints.rewindSeek), findsOneWidget);
    expect(find.text(t.controllerHints.forwardSeek), findsOneWidget);
  });

  testWidgets('gamepad service hasActiveTabHandler returns false when no handlers registered', (tester) async {
    GamepadService.debugClearTabNavigationHandlers();
    expect(GamepadService.hasActiveTabHandler(), false);
  });

  testWidgets('gamepad service hasActiveTabHandler returns true when an active handler exists', (tester) async {
    GamepadService.debugClearTabNavigationHandlers();
    GamepadService.registerTabNavigation(
      'test_owner',
      previous: () {},
      next: () {},
      isActive: () => true,
    );

    expect(GamepadService.hasActiveTabHandler(), true);

    GamepadService.unregisterTabNavigation('test_owner');
  });

  testWidgets('gamepad service hasActiveTabHandler returns false when handler is inactive', (tester) async {
    GamepadService.debugClearTabNavigationHandlers();
    GamepadService.registerTabNavigation(
      'test_owner',
      previous: () {},
      next: () {},
      isActive: () => false,
    );

    expect(GamepadService.hasActiveTabHandler(), false);

    GamepadService.unregisterTabNavigation('test_owner');
  });
}
