module InheritanceTest
using ComputedFieldTypes
using Base.Test

abstract type Bar end

@computed struct Parametric{T} <: Bar
    x::Base.promote_op(+, T, Float64)
end

@computed struct NonParametric <: Bar
    x::Base.promote_op(+, Int, Float64)
end

@testset "inheritance" begin
    @test isa(@inferred(Parametric{Int}(1)), Parametric{Int, Float64})
    @test isa(@inferred(Parametric{Float64}(1.0)), Parametric{Float64, Float64})

    @test isa(@inferred(NonParametric(1)), NonParametric{Float64})
end
end
