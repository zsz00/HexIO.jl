using StructIO
using Compat
using Base.Test

@io immutable TwoUInts
    x::UInt
    y::UInt
end

buf = IOBuffer()
write(buf, UInt(1))
write(buf, UInt(2))
seekstart(buf)
@test unpack(buf, TwoUInts) == TwoUInts(1,2)

@compat abstract type SomeAbstractType end
@io immutable SomeConcreteType <: SomeAbstractType
    A::UInt32
    B::UInt16
    C::UInt32
    D::UInt8
end align_packed

@io immutable ParametricType{S,T}
    A::S
    B::T
    C::T
end
