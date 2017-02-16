# StructIO

[![StructIO](http://pkg.julialang.org/badges/StructIO_0.5.svg)](http://pkg.julialang.org/?pkg=StructIO)
[![Build Status](https://travis-ci.org/Keno/StructIO.jl.svg?branch=master)](https://travis-ci.org/Keno/StructIO.jl)

Generates IO methods (`sizeof`, `pack`, `unpack`) from structure definitions.

# Example usage
```julia
julia> using StructIO

julia> @io struct TwoUInt64s
           x::UInt64
           y::UInt64
       end

julia> buf = IOBuffer(collect(UInt8(1):UInt8(16))); 

julia> seekstart(buf); unpack(buf, TwoUInt64s) # Default endianness depends on machine
TwoUInt64s(0x0807060504030201, 0x100f0e0d0c0b0a09)

julia> seekstart(buf); unpack(buf, TwoUInt64s, :BigEndian)
TwoUInt64s(0x0102030405060708, 0x090a0b0c0d0e0f10)

```
