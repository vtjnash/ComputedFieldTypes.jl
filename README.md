# ComputedFieldTypes

Build types in Julia where some fields have computed types.

# Examples

Note that the following is not idiomatic Julia, and is probably not the most efficient solutions.
They are simply intended as demonstrations of `ComputedFieldTypes`.

For simple cases, a default constructor will be added, if none is specified:

```julia
@computed struct A{V <: AbstractVector}
    a::eltype(V)
end
a = A{Vector{Int}}(3.0)
a.a === Int(3)
```

It is also possible to declare your own constructor,
with extra type variables, parameterized, etc.:

```julia
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
```

If you need a fully expanded type definition (for example, for use as a field of another `@computed` type),
you can call `fulltype(T)` on any Type `T`.
Note, however, that since this is not the canonical form, it does not have any constructors defined for it.
