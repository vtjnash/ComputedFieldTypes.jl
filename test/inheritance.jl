module InheritanceTest
using ComputedFieldTypes
using Test

abstract type Bar end

@computed struct Parametric{T} <: Bar
    x::Base.promote_op(+, T, Float64)
end

@computed struct NonParametric <: Bar
    x::Base.promote_op(+, Int, Float64)
end

@computed struct NonParametricNoParent
    x::Base.promote_op(+, Int, Float64)
end

@testset "inheritance" begin
    @test isa(@inferred(Parametric{Int}(1)), Parametric{Int, Float64})
    @test isa(Parametric{Int}(1), Bar)
    @test isa(@inferred(Parametric{Float64}(1.0)), Parametric{Float64, Float64})

    @test isa(@inferred(NonParametric(1)), NonParametric{Float64})
    @test isa(NonParametric(1), Bar)

    @test isa(@inferred(NonParametricNoParent(1)), NonParametricNoParent{Float64})
    @test !isa(NonParametricNoParent(1), Bar)
end
end


