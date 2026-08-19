import Foundation
import SwiftData

/// There's no backend or background execution in this app, so recurring rules can only fire
/// when the app is actually opened. This runs on every launch and catches up on any months
/// that were missed while the app was closed, generating one MoneyTransaction per elapsed month.
enum RecurringTransactionProcessor {
    static func processDueTransactions(context: ModelContext, today: Date = .now) {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<RecurringTransaction>(predicate: #Predicate { $0.isActive })
        guard let rules = try? context.fetch(descriptor), !rules.isEmpty else { return }

        var didProcess = false

        for rule in rules {
            // A rule never backfills the month it was created in — it starts applying from the
            // following month, so setting up "nómina día 1" mid-month doesn't retroactively add
            // an entry for a month the user may have already accounted for by hand.
            let baseDate = rule.lastRunDate ?? rule.createdAt
            guard let baseMonthStart = calendar.dateInterval(of: .month, for: baseDate)?.start,
                  var cursorMonth = calendar.date(byAdding: .month, value: 1, to: baseMonthStart) else { continue }

            while let occurrence = occurrenceDate(forMonthStarting: cursorMonth, dayOfMonth: rule.dayOfMonth, calendar: calendar),
                  occurrence <= today {
                let transaction = MoneyTransaction(
                    amount: rule.signedAmount,
                    currency: rule.currency,
                    date: occurrence,
                    transactionDescription: rule.transactionDescription,
                    source: .manual,
                    account: rule.account,
                    category: rule.category
                )
                context.insert(transaction)
                rule.account?.currentBalance += rule.signedAmount
                rule.lastRunDate = occurrence
                didProcess = true

                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursorMonth) else { break }
                cursorMonth = nextMonth
            }
        }

        if didProcess {
            try? context.save()
        }
    }

    private static func occurrenceDate(forMonthStarting monthStart: Date, dayOfMonth: Int, calendar: Calendar) -> Date? {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let clampedDay = min(dayOfMonth, range.count)
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = clampedDay
        return calendar.date(from: components)
    }
}
