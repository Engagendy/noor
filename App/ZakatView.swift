import DesignSystem
import SwiftUI

/// Offline zakat calculator. Nothing leaves the device; the gold price is
/// entered by hand (offline-first — no market API).
struct ZakatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @AppStorage("zakat.goldPrice") private var goldPricePerGram = 0.0
    @State private var cash = ""
    @State private var goldGrams = ""
    @State private var silverGrams = ""
    @State private var investments = ""
    @State private var businessGoods = ""
    @State private var moneyOwedToYou = ""
    @State private var debtsDue = ""

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private func value(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: "،", with: ".")
                   .replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Nisab = value of 85g of gold (the commonly used gold standard).
    private var nisab: Double { 85 * goldPricePerGram }

    private var totalAssets: Double {
        value(cash) + value(goldGrams) * goldPricePerGram
            + value(silverGrams) * (goldPricePerGram / 90)  // rough silver ≈ gold/90 if unknown
            + value(investments) + value(businessGoods) + value(moneyOwedToYou)
    }

    private var zakatBase: Double { max(0, totalAssets - value(debtsDue)) }
    private var isDue: Bool { goldPricePerGram > 0 && zakatBase >= nisab }
    private var zakatAmount: Double { zakatBase * 0.025 }

    private func moneyField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(NoorColor.inkPrimary)
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(width: 120)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Gold price per gram")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        TextField("0", value: $goldPricePerGram, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .frame(width: 120)
                    }
                } header: {
                    Text("Your currency")
                } footer: {
                    Text("Enter today's local gold price — the nisab is the value of 85 grams of gold.")
                }

                Section {
                    moneyField("Cash (in hand and bank)", text: $cash)
                    moneyField("Gold (grams)", text: $goldGrams)
                    moneyField("Silver (grams)", text: $silverGrams)
                    moneyField("Investments / shares", text: $investments)
                    moneyField("Business inventory", text: $businessGoods)
                    moneyField("Money owed to you", text: $moneyOwedToYou)
                    moneyField("Debts due now (subtract)", text: $debtsDue)
                } header: {
                    Text("Zakatable wealth")
                }

                Section {
                    if goldPricePerGram <= 0 {
                        Text("Enter the gold price to compute the nisab.")
                            .foregroundStyle(NoorColor.inkSecondary)
                    } else {
                        HStack {
                            Text("Nisab")
                            Spacer()
                            Text(verbatim: nisab.formatted(.number.precision(.fractionLength(0...2))))
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                        HStack {
                            Text("Net wealth")
                            Spacer()
                            Text(verbatim: zakatBase.formatted(.number.precision(.fractionLength(0...2))))
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                        if isDue {
                            HStack {
                                Text("Zakat due (2.5%)")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text(verbatim: zakatAmount.formatted(.number.precision(.fractionLength(0...2))))
                                    .font(.system(size: 17, weight: .bold).monospacedDigit())
                                    .foregroundStyle(NoorColor.accentPrimary)
                            }
                        } else {
                            Text("Below the nisab — no zakat is due.")
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                    }
                } header: {
                    Text("Result")
                } footer: {
                    Text("Zakat is due when net zakatable wealth has remained at or above the nisab for one full hijri year. This calculator is a guide — consult a scholar for complex cases. All figures stay on your device.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            #if os(iOS)
            // Swiping the form or tapping Done puts the number pad away.
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            #endif
            .navigationTitle(Text("Zakat Calculator"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
