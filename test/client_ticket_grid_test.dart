import 'package:dartkds/ui/client/client_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometry of the client's ticket board.
///
/// The regression: the grid sized its tiles with `childAspectRatio: 1.05`, so a
/// ticket's height came from its width and a 12-item order on a 1080p board got
/// ~240px of item list — about two rows. The rest of the ticket scrolled with no
/// scrollbar, no edge fade and no count of what was hidden, so a chef could not
/// tell there was anything below the fold (issue #6).
///
/// Most of these read the delegate directly, and the one that matters most lays
/// a real `GridView` out and measures a child. Neither pumps `ClientHome`, which
/// would drag in a websocket and mDNS discovery.
void main() {
  // 1920x1080 landscape tablet, minus the 60px header.
  const tabletBoard = (width: 1920.0, height: 1020.0);

  SliverGridDelegateWithFixedCrossAxisCount build(double w, double h) =>
      ticketGridDelegate(
        maxWidth: w,
        maxHeight: h,
      ) as SliverGridDelegateWithFixedCrossAxisCount;

  group('ticketGridDelegate', () {
    test('gives a tile the full board height', () {
      // 8px grid padding on all sides (16) plus the 8px main-axis spacing under
      // the single row. The tile takes everything else.
      expect(
        build(tabletBoard.width, tabletBoard.height).mainAxisExtent,
        tabletBoard.height - 24,
      );
    });

    testWidgets('lays a tile out at the full board height, not an aspect ratio', (
      tester,
    ) async {
      // The assertion that actually matters. Reading `childAspectRatio` back is
      // no use as a check: the field is a non-nullable `double` defaulting to
      // 1.0 whether or not it was passed, and the delegate resolves the extent
      // as `mainAxisExtent ?? crossAxisExtent / childAspectRatio`. So the only
      // honest check is to measure a real child.
      //
      // 8px grid padding (16) + 8px main-axis spacing leaves 576 of the 600.
      const board = Size(800, 600);

      final key = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: board.width,
                height: board.height,
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: ticketGridDelegate(
                    maxWidth: board.width,
                    maxHeight: board.height,
                  ),
                  itemCount: 1,
                  itemBuilder: (context, _) =>
                      SizedBox.expand(key: key, child: const Text('ticket')),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(key));

      expect(rect.height, board.height - 24);
      // And explicitly not the old behaviour: the tile was previously sized by
      // `childAspectRatio: 1.05` off its 256px width, i.e. ~244px tall.
      expect(rect.height, isNot(closeTo(rect.width / 1.05, 1)));
    });

    test('keeps deriving the column count from the width', () {
      expect(build(1920, 1020).crossAxisCount, 8); // 1920 / 240
      expect(build(1200, 1020).crossAxisCount, 5);
      expect(build(640, 1020).crossAxisCount, 2);
    });

    test('clamps the column count at both ends', () {
      expect(build(400, 1020).crossAxisCount, 1); // below one column's worth
      expect(build(40000, 1020).crossAxisCount, 14); // ultrawide
    });

    test('does not hand out a tile taller than the board', () {
      // The whole point: a tall board must not be squashed back to a fixed
      // aspect, and a short one must not overflow the viewport.
      expect(
        build(1920, 1020).mainAxisExtent!,
        lessThan(1020),
      );
    });

    test('clamps to a floor on a very short board', () {
      // Degrades to too-small-to-read rather than a negative or zero extent.
      expect(build(1920, 60).mainAxisExtent, 120);
      expect(build(1920, 10).mainAxisExtent, 120);
    });

    test('survives a non-finite height', () {
      // The grid sits in an `Expanded`, so height is tight in practice — but a
      // NaN extent throws during layout, so the guard is what keeps a stray
      // unbounded constraint from taking the board down.
      expect(build(1920, double.infinity).mainAxisExtent, 120);
      expect(build(1920, double.nan).mainAxisExtent, 120);
    });

    test('grows the tile as the board grows', () {
      // A short board still yields more height than the old fixed ratio did at
      // the same width, which is the difference the issue was about.
      final short = build(1920, 500).mainAxisExtent!;
      final tall = build(1920, 1020).mainAxisExtent!;

      expect(tall, greaterThan(short));
      expect(tall, tabletBoard.height - 24);
    });
  });
}