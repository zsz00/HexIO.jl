using StructIO
using Base.Test

@struct immutable TwoUInts
    x::UInt
    y::UInt
end

buf = IOBuffer()
write(buf, UInt(1))
write(buf, UInt(2))
seekstart(buf)
@test unpack(buf, TwoUInts) == TwoUInts(1,2)

abstract SomeAbstractType
@struct immutable SomeConcreteType <: SomeAbstractType
    A::UInt32
    B::UInt16
    C::UInt32
    D::UInt8
end align_packed

@struct immutable ParametricType{S,T}
    A::S
    B::T
    C::T
end
