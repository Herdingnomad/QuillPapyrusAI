import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/native_picker_launcher_dialog.dart';

void main() {
  group('NativePickerLauncherDialog Tests', () {
    testWidgets('Renders launcher dialog with Back and Cancel buttons, and Cancel/Back button pops null', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await NativePickerLauncherDialog.showDirectoryPicker(
                    context,
                    title: 'Choose Workspace Folder',
                    subtitle: 'Browse device storage or enter a folder path.',
                    actionButtonLabel: 'Open System Folder Picker',
                    allowManualPath: true,
                    onLaunchPicker: () async => null,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Title, Subtitle, and Buttons are rendered
      expect(find.text('Choose Workspace Folder'), findsOneWidget);
      expect(find.text('Browse device storage or enter a folder path.'), findsOneWidget);
      expect(find.text('Open System Folder Picker'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNWidgets(2)); // Top back button & bottom action
      expect(find.byIcon(Icons.close_rounded), findsOneWidget); // Top cancel button
      expect(find.text('Cancel / Back'), findsOneWidget); // Bottom action button

      // Tap bottom 'Cancel / Back' button
      await tester.tap(find.text('Cancel / Back'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and result is null
      expect(find.byType(NativePickerLauncherDialog<String>), findsNothing);
      expect(result, isNull);
    });

    testWidgets('Top navigation back button dismisses picker launcher', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await NativePickerLauncherDialog.showDirectoryPicker(
                    context,
                    title: 'Select Folder',
                    subtitle: 'Open native file manager.',
                    onLaunchPicker: () async => null,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap top-left back button
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(NativePickerLauncherDialog<String>), findsNothing);
      expect(result, isNull);
    });

    testWidgets('Top navigation cancel button dismisses picker launcher', (tester) async {
      List<String>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await NativePickerLauncherDialog.showFilePicker(
                    context,
                    title: 'Select PDF Document',
                    subtitle: 'Choose a PDF using native file manager.',
                    onLaunchPicker: () async => null,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap top-right close button
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(NativePickerLauncherDialog<List<String>>), findsNothing);
      expect(result, isNull);
    });

    testWidgets('While native picker is running, shows active state with Back out of Picker / Cancel button', (tester) async {
      final pickerCompleter = Completer<String?>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await NativePickerLauncherDialog.showDirectoryPicker(
                    context,
                    title: 'Choose Workspace Folder',
                    subtitle: 'Browse storage.',
                    onLaunchPicker: () => pickerCompleter.future,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap 'Open System Folder Picker' to trigger native picker
      await tester.tap(find.text('Open System Folder Picker'));
      await tester.pump();

      // Active state is shown with progress indicator and 'Back out of Picker / Cancel' button
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Native File Picker is active'), findsOneWidget);
      expect(find.text('Back out of Picker / Cancel'), findsOneWidget);

      // Tap the prominent back out button
      await tester.tap(find.text('Back out of Picker / Cancel'));
      await tester.pumpAndSettle();

      // Dialog is dismissed cleanly
      expect(find.byType(NativePickerLauncherDialog<String>), findsNothing);
    });
  });
}
