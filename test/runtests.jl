module InheritanceTest
using ComputedFieldTypes
using Base.Test

abstract type Bar end

@computed struct Foo{T} <: Bar
    x::Base.promote_op(+, T, Float64)
end

@testset "inheritance" begin
    @test isa(@inferred(Foo{Int}(1)), Foo{Int, Float64})
    @test isa(@inferred(Foo{Float64}(1.0)), Foo{Float64, Float64})
end
end
