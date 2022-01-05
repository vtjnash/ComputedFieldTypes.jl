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

@computed struct ParametricRef{T}
    x::Base.RefValue{Some{T}}
    y::getfield(Base,:RefValue){Some{T}}
    ParametricRef(x::Some{T}) where {T} = new{T}(Ref(x), Ref(x))
end

@computed struct ParametricWhere{T}
    a::Pair{S, Some{T}} where S
    b::Pair{S, Some{T}} where S<:typeassert(T,DataType)
    c::Pair{S, Some{T}} where S>:(T::DataType)
    d::Pair{S, Some{T}} where typeassert(T,DataType)<:S<:typeassert(T,DataType)
    ## this is currently illegal, since we cannot determine when to compute identity(S):
    # x::Pair{identity(S), Some{T}} where S
    function ParametricWhere(x::Some{T}) where {T}
        p = something(x) => x
        return new{T}(p, p, p, p)
    end
end

@testset "nested expressions" begin
    @test isa(@inferred(ParametricRef(Some(1.0))), ParametricRef{Float64})
    T = typeof(ParametricRef(Some(1)))
    @test T === fulltype(ParametricRef{Int})
    @test isa(ParametricRef(Some(1)).x[], Some{Int})
    @test isa(ParametricRef(Some(1)).y[], Some{Int})

    @test isa(@inferred(ParametricWhere(Some(1.0))), ParametricWhere{Float64})
    T = typeof(ParametricWhere(Some(1)))
    @test T === fulltype(ParametricWhere{Int})
    @test fieldtype(T, :a) === Pair{S, Some{Int}} where S
    @test fieldtype(T, :b) === Pair{S, Some{Int}} where S<:Int
    @test fieldtype(T, :c) === Pair{S, Some{Int}} where S>:Int
    @test fieldtype(T, :d) === Pair{S, Some{Int}} where Int<:S<:Int
end

end
