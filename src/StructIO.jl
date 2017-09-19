__precompile__()
module StructIO

using Base: @pure
using Base.Meta
using Compat
export @io, unpack, pack, fix_endian

needs_bswap(endianness) = (ENDIAN_BOM == 0x01020304) ?
    endianness == :LittleEndian : endianness == :BigEndian
fix_endian(x, endianness) = needs_bswap(x) ? bswap(x) : x

# Alignment traits
@compat abstract type PackingStrategy end
immutable Packed <: PackingStrategy; end
immutable Default <: PackingStrategy; end
function strategy
end

# Sizeof computation
round_up(offset, alignment) = offset +
    mod(alignment - mod(offset, alignment), alignment)

@pure function sizeof(T::DataType, ::Type{Default})
    Core.sizeof(T)
end

@pure function sizeof(T::DataType, ::Type{Packed})
    @assert nfields(T) != 0 && isbits(T)
    sum(sizeof, T.types)
end
sizeof(T::DataType) = sizeof(T, nfields(T) == 0 ? Default : strategy(T))

# Generates methods for unpack!, pack!, and sizeof
macro io(typ, annotations...)
    alignment = :align_default
    if length(annotations) == 1
        ann = annotations[1]
        if isa(ann, Symbol) || haskey(alignments, ann)
            alignment = ann
        end
    end
    typname = typ.args[2]
    isexpr(typname,:(<:)) && (typname = typname.args[1])
    isexpr(typname,:curly) && (typname = typname.args[1])
    ret = Expr(:toplevel, typ)
    if alignment == :align_default
        push!(ret.args, :(StructIO.strategy(::Type{$typname}) = StructIO.Default))
    else
        @assert alignment == :align_packed
        push!(ret.args, :(StructIO.strategy(::Type{$typname}) = StructIO.Packed))
    end
    push!(ret.args, :(Base.sizeof(::Type{$typname}) = StructIO.sizeof($typname)))
    push!(ret.args, :(Base.sizeof(::$typname) = StructIO.sizeof($typname)))
    esc(ret)
end

function unsafe_unpack(io::IO, T::Type, target, endianness, ::Type{Default})
    if nfields(T) == 0
        sz = Core.sizeof(T)
        unsafe_read(io, target, sz)
        if needs_bswap(endianness)
            # Special case small sizes, LLVM should turn this into a jump
            # table
            if sz == 1
            elseif sz == 2
                ptr = Base.unsafe_convert(Ptr{UInt16}, target)
                unsafe_store!(ptr, bswap(unsafe_load(ptr)))
            elseif sz == 4
                ptr = Base.unsafe_convert(Ptr{UInt32}, target)
                unsafe_store!(ptr, bswap(unsafe_load(ptr)))
            elseif sz == 8
                ptr = Base.unsafe_convert(Ptr{UInt64}, target)
                unsafe_store!(ptr, bswap(unsafe_load(ptr)))
            else
                for i = 0:div(sz,2)
                    ptrhigh = Base.unsafe_convert(Ptr{UInt8}, target) + 8*(sz-i)
                    ptrlow = Base.unsafe_convert(Ptr{UInt8}, target) + 8*i
                    high = unsafe_load(ptrhigh)
                    low = unsafe_load(ptrlow)
                    unsafe_store(ptrhigh, low)
                    unsafe_store(ptrlow, high)
                end
            end
        end
    elseif !needs_bswap(endianness)
        sz = Core.sizeof(T)
        unsafe_read(io, target, sz)
    else
        reached = 0
        for i = 1:nfields(T)
            fT = fieldtype(T, i)
            foffs = fieldoffset(T, i)
            skip(io, reached - foffs)
            reached = foffs
            unsafe_unpack(io, fT,
                Base.unsafe_convert(Ptr{Void}, target) + foffs, endianness, Default)
            reached += Core.sizeof(fT)
        end
    end
end

function unsafe_unpack(io::IO, T::Type, target, endianness, ::Type{Packed})
    nfields(T) == 0 && return unsafe_unpack(io, T, target, endianness, Default)
    for i = 1:nfields(T)
        fT = fieldtype(T, i)
        unsafe_unpack(io, fT,
            Base.unsafe_convert(Ptr{Void}, target) + fieldoffset(T, i), endianness, Packed)
    end
end

function unpack(io::IO, T::Type, endianness = :NativeEndian)
    r = Ref{T}()
    unsafe_unpack(io, T, r, endianness, nfields(T) == 0 ? Default : strategy(T))
    r[]
end

end # module
