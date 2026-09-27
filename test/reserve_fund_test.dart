import 'package:flutter_test/flutter_test.dart';
import 'package:nestmate/models/expense.dart';
import 'package:nestmate/providers/society_provider.dart';

void main() {
  test('reserve fund top-up, spend, delete, and insufficient-balance guard', () async {
    final society = SocietyProvider.mock();
    expect(society.building.reserveFundPaise, 0);

    // Top up ₹5,000/flat × 15 flats = ₹75,000.
    await society.topUpReserveFund(500000 * 15);
    expect(society.building.reserveFundPaise, 7500000);

    final commonPoolBefore = society.currentMonth.commonPoolPaise;

    // Spend ₹3,000 from the reserve — must not touch commonPoolPaise.
    final ok = await society.addExpense(
      Expense(
        id: 'exp-reserve-1',
        name: 'Reserve-funded repair',
        category: 'Repairs',
        amountPaise: 300000,
        fundedByReserve: true,
      ),
    );
    expect(ok, true);
    expect(society.building.reserveFundPaise, 7200000);
    expect(society.currentMonth.commonPoolPaise, commonPoolBefore);

    // Delete it — balance should return exactly to 75,000.
    await society.deleteExpense('exp-reserve-1');
    expect(society.building.reserveFundPaise, 7500000);

    // Try to spend more than the balance — must be rejected, balance
    // unchanged, and nothing added to the expense list.
    final expenseCountBefore = society.currentMonth.expenses.length;
    final rejected = await society.addExpense(
      Expense(
        id: 'exp-reserve-2',
        name: 'Too much',
        category: 'Repairs',
        amountPaise: 8000000,
        fundedByReserve: true,
      ),
    );
    expect(rejected, false);
    expect(society.building.reserveFundPaise, 7500000);
    expect(society.currentMonth.expenses.length, expenseCountBefore);

    // Edit a reserve-funded expense's amount — delta must adjust correctly.
    final added = await society.addExpense(
      Expense(
        id: 'exp-reserve-3',
        name: 'Adjustable',
        category: 'Repairs',
        amountPaise: 100000,
        fundedByReserve: true,
      ),
    );
    expect(added, true);
    expect(society.building.reserveFundPaise, 7400000);

    final edited = await society.updateExpense(
      Expense(
        id: 'exp-reserve-3',
        name: 'Adjustable',
        category: 'Repairs',
        amountPaise: 250000,
        fundedByReserve: true,
      ),
    );
    expect(edited, true);
    expect(society.building.reserveFundPaise, 7250000);

    // Flip it back to normal (split-across) funding — full refund.
    final unflagged = await society.updateExpense(
      Expense(
        id: 'exp-reserve-3',
        name: 'Adjustable',
        category: 'Repairs',
        amountPaise: 250000,
        fundedByReserve: false,
      ),
    );
    expect(unflagged, true);
    expect(society.building.reserveFundPaise, 7500000);
  });
}
