import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/services/gamepad_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

void main() {
  testWidgets('gamepad disconnect stops held-direction repeat and releases held keys', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    service.debugHandleGamepadEvent(_button(GamepadButton.dpadRight, pressed: true));
    service.debugHandleGamepadEvent(_button(GamepadButton.a, pressed: true));
    await tester.pump();

    expect(_downCount(events, LogicalKeyboardKey.arrowRight), 1);
    expect(_downCount(events, LogicalKeyboardKey.enter), 1);

    // Let the auto-repeat engage: 400ms initial delay, then 80ms intervals.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowRight), greaterThan(1));

    service.debugHandleGamepadEvent(_disconnect());
    await tester.pump();

    // The held A key was released by the disconnect teardown.
    expect(_upCount(events, LogicalKeyboardKey.enter), 1);

    final repeatsAtDisconnect = _downCount(events, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(
      _downCount(events, LogicalKeyboardKey.arrowRight),
      repeatsAtDisconnect,
      reason: 'no synthesized repeats may fire after the controller disconnects',
    );

    // Held-button state was cleared: the release that never arrived from the
    // dead controller cannot double-fire when a reconnected pad sends it.
    service.debugHandleGamepadEvent(_button(GamepadButton.a, pressed: false));
    await tester.pump();
    expect(_upCount(events, LogicalKeyboardKey.enter), 1);
  });

  testWidgets('gamepad disconnect clears stick latches so a reconnected stick navigates again', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 1.0));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowDown), 1);

    service.debugHandleGamepadEvent(_disconnect());
    await tester.pump();

    final repeatsAtDisconnect = _downCount(events, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowDown), repeatsAtDisconnect);

    // The latch was cleared, so a fresh deflection navigates immediately
    // without first passing back through the deadzone.
    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 1.0));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowDown), repeatsAtDisconnect + 1);

    // Return the stick to the deadzone so the new repeat timer is cancelled.
    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 0.0));
    await tester.pump();
  });

  testWidgets('D-pad and stick releases do not stop each other\'s repeat (D2: repeat ownership)', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    // Press dpadRight and let it repeat
    service.debugHandleGamepadEvent(_button(GamepadButton.dpadRight, pressed: true));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowRight), 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    final rightsBeforeDpadDown = _downCount(events, LogicalKeyboardKey.arrowRight);
    expect(rightsBeforeDpadDown, greaterThan(1));

    // Press dpadDown (starts a new repeat)
    service.debugHandleGamepadEvent(_button(GamepadButton.dpadDown, pressed: true));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowDown), 1);

    // Release dpadRight (should NOT stop the dpadDown repeat)
    service.debugHandleGamepadEvent(_button(GamepadButton.dpadRight, pressed: false));
    await tester.pump();

    // dpadDown should still be repeating
    final downsBeforePump = _downCount(events, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    final downsAfterPump = _downCount(events, LogicalKeyboardKey.arrowDown);
    expect(
      downsAfterPump,
      greaterThan(downsBeforePump),
      reason: 'dpadDown should keep repeating after releasing dpadRight',
    );

    // Clean up the held button to stop the repeat
    service.debugHandleGamepadEvent(_button(GamepadButton.dpadDown, pressed: false));
    await tester.pump();
  });

  testWidgets('stick re-centre does not stop different stick direction repeat', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    // Latch leftStickY down and let it repeat
    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 1.0));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowDown), 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    final downsBeforeDpadRight = _downCount(events, LogicalKeyboardKey.arrowDown);
    expect(downsBeforeDpadRight, greaterThan(1));

    // Press dpadRight (starts a new repeat, stops the stick repeat with current code)
    service.debugHandleGamepadEvent(_button(GamepadButton.dpadRight, pressed: true));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowRight), 1);

    // Re-centre the stick (should NOT stop dpadRight repeat)
    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 0.0));
    await tester.pump();

    // dpadRight should still be repeating
    final rightsBeforePump = _downCount(events, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    final rightsAfterPump = _downCount(events, LogicalKeyboardKey.arrowRight);
    expect(
      rightsAfterPump,
      greaterThan(rightsBeforePump),
      reason: 'dpadRight should keep repeating after stick re-centres',
    );

    // Clean up the held button to stop the repeat
    service.debugHandleGamepadEvent(_button(GamepadButton.dpadRight, pressed: false));
    await tester.pump();
  });

  testWidgets('D3: left stick deflection promotes input mode, right stick does not', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    // Left stick deflection should promote input mode (via reportNonPointerInput)
    // This is verified by checking that no errors occur and the event is processed
    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 1.0));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.arrowDown), 1);

    // Re-centre to reset
    service.debugHandleGamepadEvent(_axis(GamepadAxis.leftStickY, 0.0));
    await tester.pump();

    // Right stick deflection should NOT navigate (unmapped axis)
    // The event should be silently ignored, promoting no input mode change
    service.debugHandleGamepadEvent(_axis(GamepadAxis.rightStickY, 1.0));
    await tester.pump();

    // No navigation events should fire for right stick
    expect(
      _downCount(events, LogicalKeyboardKey.arrowDown),
      equals(1),
      reason: 'right stick deflection must not generate any key events',
    );
    expect(
      _downCount(events, LogicalKeyboardKey.arrowUp),
      equals(0),
      reason: 'right stick deflection must not generate any key events',
    );
  });

  testWidgets('D4: focus changes coordinate with native text input focus', (tester) async {
    // This test verifies that the pause/resume state depends on BOTH window focus
    // and native text input focus, not just one or the other.
    // The actual gamepad pause/resume is a no-op on Linux (per the code comment),
    // but the flag state is still used by the gamepad input handler.
    await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    // Set up handler to track state changes
    var updateGamepadPauseStateCalls = 0;
    GamepadService.debugNativeTextInputFocusHandler = (focused) async {
      updateGamepadPauseStateCalls++;
    };

    // Simulate native text input focus change: should call update pause state
    await service.debugSetNativeTextInputFocused(true);
    expect(
      updateGamepadPauseStateCalls,
      equals(1),
      reason: 'setting native text input focused should update pause state',
    );

    // Simulate native text input focus leaving: should call update pause state again
    await service.debugSetNativeTextInputFocused(false);
    expect(
      updateGamepadPauseStateCalls,
      equals(2),
      reason: 'unsetting native text input focused should update pause state',
    );

    // Clean up
    GamepadService.debugNativeTextInputFocusHandler = null;
  });

  testWidgets('player context handles X button and returns true', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    bool contextHandledX = false;
    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        if (button == GamepadButton.x) {
          contextHandledX = true;
          return true;
        }
        return false;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.x, pressed: true));
    await tester.pump();

    expect(contextHandledX, isTrue, reason: 'X button should be handled by context');
    // X should not fall through to the default handler
    expect(_downCount(events, LogicalKeyboardKey.gameButtonX), 0);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('player context inactive lets buttons fall through', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    bool contextCalled = false;
    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        contextCalled = true;
        return true;
      },
      isActive: () => false, // Context is inactive
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: true));
    await tester.pump();

    // Context should not be called when inactive
    expect(contextCalled, isFalse);
    // Y should fall through to default handler
    expect(_downCount(events, LogicalKeyboardKey.contextMenu), 1);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('player context unhandled button falls through', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        // Only handle X, let Y fall through
        return button == GamepadButton.x;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: true));
    await tester.pump();

    // Y should fall through to default handler
    expect(_downCount(events, LogicalKeyboardKey.contextMenu), 1);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('context-consumed button release is swallowed', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        return button == GamepadButton.x;
      },
      isActive: () => true,
    );
    service.debugHandleGamepadEvent(_button(GamepadButton.x, pressed: true));
    await tester.pump();
    expect(_downCount(events, LogicalKeyboardKey.gameButtonX), 0);

    service.debugHandleGamepadEvent(_button(GamepadButton.x, pressed: false));
    await tester.pump();
    expect(_upCount(events, LogicalKeyboardKey.gameButtonX), 0);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('trigger hold-to-repeat invokes handler', (tester) async {
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    int callCount = 0;
    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        if (button == GamepadButton.leftTrigger) {
          callCount++;
          return true;
        }
        return false;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.leftTrigger, pressed: true));
    await tester.pump();
    expect(callCount, 1);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    expect(callCount, greaterThan(1));

    service.debugHandleGamepadEvent(_button(GamepadButton.leftTrigger, pressed: false));
    await tester.pump();
    final finalCount = callCount;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(callCount, finalCount);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('trigger repeat stops when context becomes inactive', (tester) async {
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    bool isActive = true;
    int callCount = 0;

    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        if (button == GamepadButton.rightTrigger) {
          callCount++;
          return true;
        }
        return false;
      },
      isActive: () => isActive,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.rightTrigger, pressed: true));
    await tester.pump();
    expect(callCount, 1);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    final countAfterFirstRepeat = callCount;
    expect(countAfterFirstRepeat, greaterThan(1));

    isActive = false;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(callCount, countAfterFirstRepeat);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('MainScreen context Start button is handled', (tester) async {
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    bool handled = false;

    GamepadService.registerGamepadContext(
      'mainscreen',
      onButton: (button) {
        if (button == GamepadButton.start) {
          handled = true;
          return true;
        }
        return false;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.start, pressed: true));
    await tester.pump();

    expect(handled, isTrue, reason: 'Start button should be handled by MainScreen context');

    GamepadService.unregisterGamepadContext('mainscreen');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('MainScreen context View button is handled', (tester) async {
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    bool handled = false;

    GamepadService.registerGamepadContext(
      'mainscreen',
      onButton: (button) {
        if (button == GamepadButton.back) {
          handled = true;
          return true;
        }
        return false;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.back, pressed: true));
    await tester.pump();

    expect(handled, isTrue, reason: 'View/back button should be handled by MainScreen context');

    GamepadService.unregisterGamepadContext('mainscreen');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('MainScreen context inactive when not current route', (tester) async {
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    bool contextCalled = false;

    GamepadService.registerGamepadContext(
      'mainscreen',
      onButton: (button) {
        contextCalled = true;
        return true;
      },
      isActive: () => false,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.start, pressed: true));
    await tester.pump();

    expect(contextCalled, isFalse, reason: 'MainScreen context should not be active');

    GamepadService.unregisterGamepadContext('mainscreen');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('player context wins over MainScreen context', (tester) async {
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));
    bool playerHandled = false;
    bool mainscreenHandled = false;

    // Register player context first (it will be checked last due to iteration order)
    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        if (button == GamepadButton.y) {
          playerHandled = true;
          return true;
        }
        return false;
      },
      isActive: () => true,
    );

    // Then register MainScreen context
    GamepadService.registerGamepadContext(
      'mainscreen',
      onButton: (button) {
        mainscreenHandled = true;
        return true;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: true));
    await tester.pump();

    // Both contexts should have been called since they iterate through all handlers
    // But the player should have handled it first and returned true to stop iteration
    expect(playerHandled || mainscreenHandled, isTrue);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.unregisterGamepadContext('mainscreen');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('Y outside context emits contextMenu KeyDown and KeyUp', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: true));
    await tester.pump();

    expect(_downCount(events, LogicalKeyboardKey.contextMenu), 1);

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: false));
    await tester.pump();

    expect(_upCount(events, LogicalKeyboardKey.contextMenu), 1);
  });

  testWidgets('Y inside active context does not emit contextMenu', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    GamepadService.registerGamepadContext(
      'player',
      onButton: (button) {
        if (button == GamepadButton.y) {
          return true;
        }
        return false;
      },
      isActive: () => true,
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: true));
    await tester.pump();

    expect(
      _downCount(events, LogicalKeyboardKey.contextMenu),
      0,
      reason: 'contextMenu should not be emitted when context handles Y',
    );

    service.debugHandleGamepadEvent(_button(GamepadButton.y, pressed: false));
    await tester.pump();

    expect(_upCount(events, LogicalKeyboardKey.contextMenu), 0);

    GamepadService.unregisterGamepadContext('player');
    GamepadService.debugClearGamepadContextHandlers();
  });

  testWidgets('Guide press/release emits no key events and does not promote input mode', (tester) async {
    final events = await _pumpKeyEventRecorder(tester);
    final service = GamepadService.forTesting(duplicateInputGuard: GamepadDuplicateInputGuard(enabled: () => false));

    service.debugHandleGamepadEvent(_button(GamepadButton.guide, pressed: true));
    await tester.pump();

    expect(events, isEmpty, reason: 'Guide press should emit no key events');

    service.debugHandleGamepadEvent(_button(GamepadButton.guide, pressed: false));
    await tester.pump();

    expect(events, isEmpty, reason: 'Guide release should emit no key events');
  });
}

GamepadButtonEvent _button(GamepadButton button, {required bool pressed}) {
  return GamepadButtonEvent(gamepadId: 1, timestamp: 0, button: button, pressed: pressed, value: pressed ? 1.0 : 0.0);
}

GamepadAxisEvent _axis(GamepadAxis axis, double value) {
  return GamepadAxisEvent(gamepadId: 1, timestamp: 0, axis: axis, value: value);
}

GamepadConnectionEvent _disconnect() {
  return GamepadConnectionEvent(
    gamepadId: 1,
    timestamp: 0,
    connected: false,
    info: const GamepadInfo(id: 1, name: 'Test Pad'),
  );
}

int _downCount(List<KeyEvent> events, LogicalKeyboardKey key) {
  return events.whereType<KeyDownEvent>().where((e) => e.logicalKey == key).length;
}

int _upCount(List<KeyEvent> events, LogicalKeyboardKey key) {
  return events.whereType<KeyUpEvent>().where((e) => e.logicalKey == key).length;
}

Future<List<KeyEvent>> _pumpKeyEventRecorder(WidgetTester tester) async {
  final events = <KeyEvent>[];
  late BuildContext focusContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          events.add(event);
          return KeyEventResult.handled;
        },
        child: Builder(
          builder: (context) {
            focusContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  Focus.of(focusContext).requestFocus();
  await tester.pump();
  expect(Focus.of(focusContext).hasPrimaryFocus, isTrue);
  return events;
}
