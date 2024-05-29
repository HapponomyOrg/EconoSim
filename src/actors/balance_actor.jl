using Agents

"""
    BalanceActor - agent representing an actor with a balance sheet.
"""
abstract type BalanceActor <: AbstractActor end

"""
    get_balance(actor::BalanceActor)
"""
get_balance(actor::BalanceActor) = actor.balance

function transfer_asset!(model::ABM,
                         source::BalanceActor,
                         destination::BalanceActor,
                         entry::BalanceEntry,
                         amount::Real)
    transfer_asset!(get_balance(source), get_balance(destination), entry, amount, timestamp = model.step)
end

function transfer_liability!(model::ABM,
                             source::BalanceActor,
                             destination::BalanceActor,
                             entry::BalanceEntry,
                             amount::Real)
    transfer_liability!(get_balance(source), get_balance(destination), entry, amount, timestamp = model.step)
end