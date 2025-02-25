using Test
using Agents
using DataStructures
using EconoSim

@testset "Marginality" begin
    m = Marginality([(5, 0.1), (1, 1)])

    @test typeof(m) == SortedSet{Tuple{Int64,Percentage},Base.Order.ForwardOrdering}
    @test length(m) == 2
    @test first(m) == (1, 1)
    @test last(m) == (5, 0.1)
    @test 1 <= process(m) <= 5

    m = Marginality([(1, 0.5)])
    total_units = 0
    max_want = 0

    for i in 1:1000
        units = process(m, total_units)
        max_want = max(units, max_want)
        total_units = total_units + units
    end

    @test total_units <= 1
    @test max_want <= 1
end

@testset "Needs" begin
    # Blueprints
    cb = ConsumableBlueprint("Consumable")
    pb = ProductBlueprint("Product")

    needs = Needs()

    # usage
    push_usage!(needs, cb, [(2, 1), (5, 0.5)], priority = 1)
    push_usage!(needs, pb, [(1, 1), (2, 0.1)], priority = 2)

    # wants
    push_want!(needs, cb, [(1, 1), (2, 0.5)], priority = 2)
    push_want!(needs, pb, [(1, 1)], priority = 1)

    usages = process_usage(needs)
    @test length(usages) == 2
    @test usages[1].blueprint == cb
    @test 2 <= usages[1].units <= 5
    @test usages[2].blueprint == pb
    @test 1 <= usages[2].units <= 2

    wants = process_wants(needs, Entities())
    @test length(wants) == 2
    @test wants[1].blueprint == pb
    @test wants[1].units == 1
    @test wants[2].blueprint == cb
    @test 1 <= wants[2].units <= 2
end

@testset "Economic Assets" begin
    # Blueprints
    cb = ConsumableBlueprint("Consumable")
    pb = ProductBlueprint("Product")

    #Products
    pb1 = ProducerBlueprint("Producer 1")
    pb1.batch[cb] = 3
    p1 = Producer(pb1)

    pb2 = ProducerBlueprint("Producer 2")
    pb2.batch[pb] = 1
    p2 = Producer(pb2)

    posessions = Entities()
    push!(posessions, Consumable(cb))
    balance = Balance()
    book_asset!(balance, BalanceEntry("C"), 100)
    model = create_econo_model()
    person = create_monetary_actor!(model, types = Set([:person]))
    make_economic_actor!(person, posessions = posessions, producers = Set([p1, p2]))

    @test length(producers(person)) == 2
    @test p1 in producers(person)
    @test p2 in producers(person)
end

@testset "Marginal actor" begin
    # Blueprints
    cb = ConsumableBlueprint("Consumable")
    pb = ProductBlueprint("Product")

    #Products
    pb1 = ProducerBlueprint("Producer 1")
    pb1.batch[cb] = 3
    p1 = Producer(pb1)

    pb2 = ProducerBlueprint("Producer 2")
    pb2.batch[pb] = 1
    p2 = Producer(pb2)

    # Needs
    needs = Needs()
    push_usage!(needs, cb, [(2, 1), (5, 0.5)], priority = 1)
    push_usage!(needs, pb, [(1, 1), (2, 0.1)], priority = 2)

    posessions = Entities()
    push!(posessions, Consumable(cb))
    balance = Balance()
    book_asset!(balance, BalanceEntry("C"), 100)
    model = create_econo_model()
    person = create_monetary_actor!(model, balance = balance, types = Set([:person]))
    make_economic_actor!(person, posessions = posessions, producers = Set([p1, p2]))
    make_marginal!(person, needs = needs)

    @test length(producers(person)) == 2
    @test p1 in producers(person)
    @test p2 in producers(person)

    @test person.needs == needs
end

@testset "Model - marginal - trade" begin
    # money = BalanceEntry("Money")

    # cbp1 = ConsumableBlueprint("C1")
    # pbp1 = ProducerBlueprint("P1", batch = Dict([(cbp1 => 10)]))
    # p1 = Producer(pbp1)

    # cbp2 = ConsumableBlueprint("C2")
    # pbp2 = ProducerBlueprint("P2", batch = Dict([(cbp2 => 10)]))
    # p2 = Producer(pbp2)

    # actor1 = EconomicActor(1, producers = [p1])
    # book_asset!(actor1.balance, money, 100)
    # needs = Needs()
    # push_want!(needs, cbp2, [(2, 1)])
    # push_usage!(needs, cbp2, [(1, 1)])
    # make_marginal!(actor1, needs = needs)
    # min_stock!(actor1.stock, cbp1, 10)

    # actor2 = EconomicActor(2, producers = [p2])
    # book_asset!(actor2.balance, money, 100)
    # needs = Needs()
    # push_want!(needs, cbp1, [(2, 1)])
    # push_usage!(needs, cbp1, [(1, 1)])
    # make_marginal!(actor2, needs = needs)
    # min_stock!(actor2.stock, cbp2, 10)

    # model = create_econo_model(EconomicActor, update_stock!)
    # set_price!(model, cbp1, Price([money => 10]))
    # set_price!(model, cbp2, Price([money => 20]))

    # add_agent!(actor1, model)
    # add_agent!(actor2, model)

    # econo_step!(model)

    # @test asset_value(actor1.balance, money) == 80
    # @test num_entities(actor1.posessions, cbp1) == 0
    # @test num_entities(actor1.posessions, cbp2) == 1
    # @test current_stock(actor1.stock, cbp1) == 8
    # @test current_stock(actor1.stock, cbp2) == 0

    # @test asset_value(actor2.balance, money) == 120
    # @test num_entities(actor2.posessions, cbp1) == 1
    # @test num_entities(actor2.posessions, cbp2) == 0
    # @test current_stock(actor2.stock, cbp1) == 0
    # @test current_stock(actor2.stock, cbp2) == 8
end

@testset "Model - stock use" begin
end
