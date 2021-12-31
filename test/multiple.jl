module Dummy

using ComputedFieldTypes
import Base: RefValue
using Test

@computed struct Foo{T <: AbstractFloat, N}
  a::Array{T, N}
  b::Array{T, N + 1}
  Foo(a::Array{T, N}) where {T, N} = new{T, N}(a, reshape(a, (size(a)..., 1)))
end

@computed struct Bar{T <: AbstractFloat, N}
  r::RefValue{Foo{T, N}}
  Bar(r::Foo{T, N}) where {T, N} = new{T, N}(Ref(r))
end

@computed struct Baz{T <: AbstractFloat, O}
  r::RefValue{Foo{T, O}}
  Baz(r::Foo{T, O}) where {T, O} = new{T, O}(Ref(r))
end

@testset "multiple" begin
  m = Float64[0 1; 2 3]
  foo = Foo(m)
  @test ndims(foo.b) == ndims(m) + 1
  @test ndims(Bar(foo).r[].b) == ndims(m) + 1
  @test_throws MethodError ndims(Baz(foo).r[].b) == ndims(m) + 1  # FIXME
end

end
