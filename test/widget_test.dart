import 'package:flutter_test/flutter_test.dart';

import 'package:dartkds/providers/intake_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('IntakeProvider adds and updates items', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(intakeProvider.notifier);
    final state = container.read(intakeProvider);

    expect(state.items, isEmpty);
    expect(state.customerName, isEmpty);
    expect(state.editingOrderUuid, isNull);

    notifier.setCustomerName('Alice');
    expect(container.read(intakeProvider).customerName, 'Alice');

    notifier.clear();
    expect(container.read(intakeProvider).items, isEmpty);
    expect(container.read(intakeProvider).customerName, isEmpty);
  });
}