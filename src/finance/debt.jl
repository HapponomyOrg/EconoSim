using UUIDs

DEPOSIT = BalanceEntry("Deposit")
DEBT = BalanceEntry("Debt")

"""
    mutable struct Debt

A transferable debt contract between two balance sheets.

* id: The unique id of the contract
* creditor: the balance sheet which receives debt payments.
* debtor: the balance sheet from which payments are deducted.
* installments: a list of installments to be paid.
* interest_rate: the interest rate on the debt.
* bank_debt: indicates whether the debt is to a bank. This has an impact on how the initial transfer of money and the downpayments are booked to the creditor's balance sheet.
* money_entry: the entry to be used to book the borrowed money.
* debt_entry: the entry to be used to book the debt.
* creation: the timestamp of the creation of the debt.
* interval: the interval between installments. This can be 0.
"""
mutable struct Debt{C <: FixedDecimal}
    id::UUID
    creditor::Balance
    debtor::Balance
    installments::Vector{C}
    interest_rate::Float64
    bank_debt::Bool
    money_entry::BalanceEntry
    debt_entry::BalanceEntry
    creation::Int64
    interval::Int64
    Debt(creditor::Balance,
        debtor::Balance,
        installments::Vector{<:Real},
        interest_rate::Real = 0;
        bank_debt::Bool = true,
        money_entry::BalanceEntry = DEPOSIT,
        debt_entry::BalanceEntry = DEBT,
        creation::Int64 = 0,
        interval = 0) = new{Currency}(uuid4(),
            creditor,
            debtor,
            installments,
            interest_rate,
            bank_debt,
            money_entry,
            debt_entry,
            creation,
            interval)
end

"""
    Debt(creditor::Balance,
        debtor::Balance,
        amount::Real,
        interest_rate::Real,
        installments::Integer;
        bank_debt::Bool = true,
        money_entry::BalanceEntry = DEPOSIT,
        debt_entry::BalanceEntry = DEBT,
        creation::Int64 = 0,
        interval::Int64 = 0)

Create a debt contract between two balances with a number of equal installments.

* creditor: the balance sheet receiving the installments.
* debtor: the balance sheet from which the installments will be subtracted.
* interest_rate: the interest rate on the debt.
* installments: the number of installments.
* bank_debt: whether or not the creditor is a bank.
* money_entry: the balance sheet entry to be used to book the borrowed money.
* debt_entry: the balance sheet entry to be used to book the debt.
"""
function Debt(creditor::Balance,
            debtor::Balance,
            amount::Real,
            interest_rate::Real,
            installments::Integer;
            bank_debt::Bool = true,
            money_entry::BalanceEntry = DEPOSIT,
            debt_entry::BalanceEntry = DEBT,
            creation::Int64 = 0,
            interval::Int64 = 0)
    installment = Currency(amount / installments)
    rest = Currency(amount) - installment * installments
    installment_vector = fill(installment, (installments))

    # Make sure the entire debt is paid off.
    installment_vector[1] = installment + rest

    return Debt(creditor, debtor, installment_vector, interest_rate; bank_debt = bank_debt, money_entry = money_entry, debt_entry = debt_entry, creation = creation, interval = interval)
end

"""
    borrow(creditor::Balance,
        debtor::Balance,
        amount::Real,
        interest_rate::Real,
        installments::Integer,
        timestamp::Int64 = 0;
        bank_loan::Bool = true,
        money_entry::BalanceEntry = DEPOSIT,
        debt_entry::BalanceEntry = DEBT,
        negative_allowed::Bool = true)

Create a debt contract between 2 balance sheets and adjust the balance sheets according to the parameters of the debt contract.

* creditor: the balance sheet receiving the installments.
* debtor: the balance sheet from which the installments will be subtracted.
* amount: the amount to be borrowed.
* interest_rate: the interest rate on the debt.
* installments: the number of installments.
* interval: the interval between the installments.
* timestamp: the current timestamp.
* bank_loan: indicates whether the creditor is a bank. If this is true new money is created to supply the money to the debtor. If this is false, money is transferred from the creditor to the debtor.
* negative_allowed: When this is true, a debtor can lend out money even when it would result in the creditor's money entry becoming negative. Otherwise only the amount available will be lent out. In case of bank loans this is ignored.
* money_entry: the balance sheet entry to be used to book the borrowed money.
* debt_entry: the balance sheet entry to be used to book the debt.
"""
function borrow(creditor::Balance,
            debtor::Balance,
            amount::Real,
            interest_rate::Real,
            installments::Integer,
            interval = 1,
            timestamp::Int64 = 0;
            bank_loan::Bool = true,
            negative_allowed::Bool = true,
            money_entry::BalanceEntry = DEPOSIT,
            debt_entry::BalanceEntry = DEBT)
    if !(bank_loan || negative_allowed)
        amount = min(asset_value(creditor, money_entry))
    end

    # adjust creditor balance
    if bank_loan
        book_liability!(creditor, money_entry, amount)
    else
        book_asset!(creditor, money_entry, -amount)
    end

    book_asset!(creditor, debt_entry, amount)

    # adjust debtor balance
    book_asset!(debtor, money_entry, amount)
    book_liability!(debtor, debt_entry, amount)

    return Debt(creditor,
                debtor,
                amount,
                interest_rate,
                installments,
                bank_debt = bank_loan,
                money_entry = money_entry,
                debt_entry = debt_entry,
                creation = timestamp,
                interval = interval)
end

function bank_loan(creditor::Balance,
            debtor::Balance,
            amount::Real,
            interest_rate::Real,
            installments::Integer,
            interval = 1,
            timestamp::Int64 = 0;
            money_entry::BalanceEntry = DEPOSIT,
            debt_entry::BalanceEntry = DEBT)
    return borrow(creditor, debtor, amount, interest_rate, installments, interval, timestamp, bank_loan = true, money_entry = money_entry, debt_entry = debt_entry)
end

function process_debt!(debt::Debt)
    if !debt_settled(debt)
        interest = sum(debt.installments) * debt.interest_rate
        installment = pop!(debt.installments)

        # adjust debtor balance
        book_asset!(debt.debtor, debt.money_entry, -(installment + interest))
        book_liability!(debt.debtor, debt.debt_entry, -installment)

        #adjust creditor balance
        if debt.bank_debt
            book_liability!(debt.creditor, debt.money_entry, -(installment + interest))
        else
            book_asset!(debt.creditor, debt.money_entry, installment + interest)
        end

        book_asset!(debt.creditor, DEBT, -installment)
    end

    return debt
end

debt_settled(debt::Debt) = isempty(debt.installments)
