import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plotshot/data/app_state.dart';
import 'package:plotshot/main.dart';
import 'package:plotshot/screens/settings/medications_screen.dart';

import 'support/fixtures.dart';

Future<void> pumpApp(WidgetTester tester, AppState state) async {
  // A typical phone size.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await initializeDateFormatting();
  await tester.pumpWidget(PlotShotApp(state: state));
  await tester.pumpAndSettle();
}

void main() {
  for (final seed in [false, true]) {
    final label = seed ? 'with data' : 'empty';

    testWidgets('every tab renders ($label)', (tester) async {
      final state = await makeState(seed: seed);
      await pumpApp(tester, state);
      expect(find.text('Jab History'), findsOneWidget);

      for (final tab in [
        'Jabs',
        'Results',
        'Calendar',
        'Settings',
        'Summary',
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });

    testWidgets('add jab screen opens ($label)', (tester) async {
      final state = await makeState(seed: seed);
      await pumpApp(tester, state);
      await tester.tap(find.text('Add jab').first);
      await tester.pumpAndSettle();
      expect(find.text('Add Jab'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every tab renders with two medications', (tester) async {
    final state = await makeState(seed: true);
    await seedSecondMedication(state);
    await pumpApp(tester, state);
    expect(find.text('Testosterone Enanthate'), findsWidgets);
    for (final tab in ['Jabs', 'Results', 'Calendar', 'Settings', 'Summary']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('Add Jab from a card preselects that medication', (tester) async {
    final state = await makeState(seed: true);
    final te = await seedSecondMedication(state);
    await pumpApp(tester, state);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jabs'),
      ),
    );
    await tester.pumpAndSettle();
    // Cards are ordered soonest due first; Test E (every 3.5 days) is first.
    await tester.tap(find.text('Add Jab').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final last = state.lastJabFor(te.id!)!;
    expect(last.doseMg, 75);
    expect(state.jabsFor(te.id!), hasLength(8));
    expect(last.site, 'Glute - Right');
  });

  testWidgets('shows the estimated level on Summary', (tester) async {
    final state = await makeState(seed: true);
    await pumpApp(tester, state);
    final level = state
        .levelOf(state.medicationsInUse.first)
        .toStringAsFixed(2);
    expect(find.textContaining(level), findsWidgets);
  });

  testWidgets('saving a jab from the editor logs it', (tester) async {
    final state = await makeState(seed: true);
    await pumpApp(tester, state);
    await tester.tap(find.text('Add jab').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.jabs, hasLength(9));
    expect(state.jabs.last.doseMg, 6);
    expect(state.jabs.last.site, 'Stomach - Lower Mid');
  });

  testWidgets('summary settings sheet opens', (tester) async {
    final state = await makeState(seed: true);
    await pumpApp(tester, state);
    await tester.tap(find.byTooltip('Customise summary'));
    await tester.pumpAndSettle();
    expect(find.text('Summary Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medication editor renders curve preview', (tester) async {
    final state = await makeState(seed: true);
    await pumpApp(tester, state);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute(
        builder: (_) =>
            MedicationEditorScreen(medication: state.medications.first),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Days between jabs'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('One 1 mg dose over 4 weeks'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('One 1 mg dose over 4 weeks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
