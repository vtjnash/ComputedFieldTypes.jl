@computed struct A{V <: AbstractVector}
    a::eltype(V)
end

@testset "basic example" begin
    a = A{Vector{Int}}(3.0)
    @test a.a === Int(3)
end

@computed struct B{N, M, T}
    a::NTuple{N + M, T}
    B(x::T) = new{N, M, T}(ntuple(i -> x, N + M))
    B{S}(x::S) = B{N, M, T}(convert(T, x))
end

@computed struct C{T <: Number}
    a::typeof(one(T) / one(T))
    C() = new(0)
    function C(x)
        return new(x)
    end
end
