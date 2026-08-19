import SwiftUI

struct TransactionRow: View {
    let transaction: MoneyTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.merchantName ?? transaction.transactionDescription)
                    .font(.body)
                if transaction.isTransfer {
                    Label("Transferencia", systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let categoryName = transaction.category?.name {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(transaction.amount, format: .currency(code: transaction.currency))
                    .foregroundStyle(amountColor)
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var amountColor: Color {
        if transaction.isTransfer { return .blue }
        return transaction.amount < 0 ? Color.primary : Color.green
    }
}
