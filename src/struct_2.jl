# 缓冲区解释, 字节解包
# 二进制数据流和字符串的结构序列化和反序列化. 类似python的 struct包.

"""
    unpack(::Type{T}, buffer::IOBuffer; buffer_lock=ReentrantLock()) where T

unpack buffer data with Type{T}. 
unpack(MyStruct, data)
"""
function unpack(buffer::IOBuffer, ::Type{T}; endianness::Symbol=:NativeEndian, buffer_lock=ReentrantLock()) where T
    return lock(buffer_lock) do
        unsafe_unpack(buffer, T, endianness)
    end
end

# Implementation Method 1
@generated function unsafe_unpack_1(buffer, ::Type{T}) where T
    ftypes = fieldtypes(T)
    l = length(ftypes)
    return :(begin
        Base.Cartesian.@nexprs $l i->a_i = read(buffer, $(ftypes)[i])
        Base.Cartesian.@ncall $l $T a
    end)
end

# Implementation Method 2
function unsafe_unpack(buffer, ::Type{T}, endianness) where T
    fieldvals = ntuple(i -> read(buffer, fieldtype(T, i)), Val(fieldcount(T)))
    return T(fieldvals...)
end


# --------------- usage ---------------  #
using BenchmarkTools

struct TLM
    a::UInt16
    b::UInt32
    c::UInt32
    d::UInt32
    e::UInt32
    f::UInt32
    g::UInt32
    h::UInt32
    i::UInt32
    j::UInt32
    k::UInt32
end

# @benchmark 
data = @btime unpack(IOBuffer(buffer), TLM; buffer_lock=lock) setup=(buffer=zeros(UInt8, 42); lock=ReentrantLock())
println(data.c)

#=
缓冲区解释, 字节解包   2022.4.21
二进制数据流和字符串的结构序列化和反序列化. 类似python的 struct包.
https://discourse.julialang.org/t/efficiently-interpreting-byte-packed-buffer/78975/32
推荐用ntuple的. 避免使用生成器总是好的.
他人测试的ntuple方式比生成器方式的快了10%, 自己测试的持平.

julia v1.7.2
99.022 ns (1 allocation: 64 bytes)     @generated
141.439 ns (1 allocation: 64 bytes)    ntuple. 感觉julia v1.7.2有性能回归

julia v1.8.0     
73.818 ns (1 allocation: 64 bytes)     @generated
73.712 ns (1 allocation: 64 bytes)     ntuple

Todo:
1. 扩展制作成个包.
2. 集成HexEdit.jl和StructIO.jl的功能

StructIO.jl 很好,比这个还好
可以把StructIO.jl和HexEdit.jl整合起来.

@io struct TLM
    a::Int16
    b::Int32
    c::Int32
    d::Int32
    e::Int32
    f::Int32
    g::Int32
    h::Int32
    i::Int32
    j::Int32
    k::Int32
end align_packed
buf = IOBuffer(zeros(UInt8, 42));
seekstart(buf); aa=unpack(buf, TLM)

buf = IOBuffer(a); seekstart(buf);
structinfo(a) = [(getfield(a, i), fieldname(typeof(a),i), fieldtype(typeof(a),i)) for i = 1:fieldcount(typeof(a))];
bb(a) = [(fieldtype(typeof(a),i)(getfield(a, i)), fieldname(typeof(a),i), fieldtype(typeof(a),i)) for i = 1:fieldcount(typeof(a))];

=#
