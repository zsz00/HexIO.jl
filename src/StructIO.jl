__precompile__()
module StructIO

using Base: @pure, bswap
using Base.Meta
using Compat
export @io, unpack, pack, fix_endian

"""
    needs_bswap(endianness::Symbol)

Returns `true` if the given endianness does not match the current host system.
"""
@pure function needs_bswap(endianness::Symbol)
    if ENDIAN_BOM == 0x01020304
        return endianness == :LittleEndian
    else
        return endianness == :BigEndian
    end
end

# Extend bswap() for pointers to arbitrarily large objects
@pure function bswap(ptr::Ptr{UInt8}, sz)
    # Count from outside edge to middle
    for i = 0:div(sz,2)
        # Swap two mirrored bytes
        ptr_hi = ptr + 8*(sz-i)
        ptr_lo = ptr + 8*i
        val_hi = unsafe_load(ptr_hi)
        val_lo = unsafe_load(ptr_lo)
        unsafe_store(ptr_hi, val_lo)
        unsafe_store(ptr_lo, val_hi)
    end
end

"""
    fix_endian(x, endianness::Symbol)

Returns a byte-swapped version of `x` if the given endianness must be swapped
for the current host system.
"""
@pure function fix_endian(x, endianness::Symbol)
    if needs_bswap(endianness)
        return bswap(x)
    end
    return x
end

# Alignment traits
@compat abstract type PackingStrategy end
immutable Packed <: PackingStrategy; end
immutable Default <: PackingStrategy; end

"""
    packing_strategy(x)

Return the packing strategy for the given type, defaults to `Default`, is
overridden by auto-generated methods for specific types from `@io` invocations.
"""
function packing_strategy(x)
    return Default
end

# Sizeof computation
@pure function round_up(offset, alignment)
    return offset + mod(alignment - mod(offset, alignment), alignment)
end

@pure function sizeof(T::DataType, ::Type{Default})
    return Core.sizeof(T)
end

@pure function sizeof(T::DataType, ::Type{Packed})
    @assert nfields(T) != 0 && isbits(T)
    return sum(sizeof, T.types)
end

@pure function sizeof(T::DataType)
    if nfields(T) == 0
        return sizeof(T, Default)
    else
        return sizeof(T, packing_strategy(T))
    end
end


"""
    @io <type definition>
        ...
    end

Generates `packing_strategy()` and `sizeof()` methods for the type being
defined within the given type definition.  This enables usage of the `unpack`
method.
"""
macro io(typ, annotations...)
    alignment = :align_default
    if length(annotations) == 1
        ann = annotations[1]
        if isa(ann, Symbol) || haskey(alignments, ann)
            alignment = ann
        end
    end
    
    # Get typename, collapsing type expressions until we get the actual type
    T = typ.args[2]
    if isexpr(T,:(<:))
        T = T.args[1]
    end
    if isexpr(T,:curly)
        T = T.args[1]
    end

    ret = Expr(:toplevel, typ)
    strat = (alignment == :align_default ? StructIO.Default : StructIO.Packed)
    push!(ret.args, :(StructIO.packing_strategy(::Type{$T}) = $strat))
    push!(ret.args, :(Base.sizeof(::Type{$T}) = StructIO.sizeof($T)))
    push!(ret.args, :(Base.sizeof(::$T) = StructIO.sizeof($T)))
    return esc(ret)
end

"""
    unsafe_unpack(io, T, target, endianness, ::Type{Default})

Unpack an object of type `T` from `io` into `target`, byte-swapping if
`endianness` dictates we should, assuming a `Default` packing strategy.  All
packed structs recurse until bitstypes objects are eventually reached, at which
point `Default` packing is the only behavior.
"""
function unsafe_unpack(io, T, target, endianness, ::Type{Default})
    if nfields(T) == 0
        # If this is a primitive data type, unpack it directly
        sz = Core.sizeof(T)
        unsafe_read(io, target, sz)
        if needs_bswap(endianness)
            # Special case small sizes, LLVM should turn this into a jump table
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
                    ptrhi = Base.unsafe_convert(Ptr{UInt8}, target) + 8*(sz-i)
                    ptrlo = Base.unsafe_convert(Ptr{UInt8}, target) + 8*i
                    hi = unsafe_load(ptrhi)
                    lo = unsafe_load(ptrlo)
                    unsafe_store(ptrhi, lo)
                    unsafe_store(ptrlo, hi)
                end
            end
        end
    elseif !needs_bswap(endianness)
        # If we don't need to bswap, just read directly into `target`
        sz = Core.sizeof(T)
        unsafe_read(io, target, sz)
    else
        # If we need to bswap, but it's not a primitive type, recurse!
        reached = 0
        target_ptr = Base.unsafe_convert(Ptr{Void}, target)
        for i = 1:nfields(T)
            # Unpack this field into `target` at the appropriate offset
            fT = fieldtype(T, i)
            foffs = fieldoffset(T, i)
            skip(io, reached - foffs)
            unsafe_unpack(io, fT, target_ptr + foffs, endianness, Default)
            reached = foffs + Core.sizeof(fT)
        end
    end
end

"""
    unsafe_unpack(io, T, target, endianness, ::Type{Packed})

Unpack an object of type `T` from `io` into `target`, byte-swapping if
`endianness` dictates we should, assuming a `Packed` packing strategy.
"""
function unsafe_unpack(io, T, target, endianness, ::Type{Packed})
    # If this type cannot be subdivided, unpack directly
    if nfields(T) == 0
        return unsafe_unpack(io, T, target, endianness, Default)
    end

    # Otherwise, iterate over the fields, unpacking each into `target`
    target_ptr = Base.unsafe_convert(Ptr{Void}, target)
    for i = 1:nfields(T)
        # Unpack this field into `target` at the appropriate offset
        fT = fieldtype(T, i)
        target_i = target_ptr + fieldoffset(T, i)
        unsafe_unpack(io, fT, target_i, endianness, Packed)
    end
end

"""
    unpack(io::IO, T::Type, endianness::Symbol = :NativeEndian)

Given an input `io`, unpack type `T`, byte-swapping according to the given
`endianness` of `io`. If `endianness` is `:NativeEndian` (the default), no
byteswapping will occur.  If `endianness` is `:LittleEndian` or `:BigEndian`,
byteswapping will occur of the endianness of the currently running host does
not match the endianness of `io`.
"""
function unpack(io::IO, T::Type, endianness::Symbol = :NativeEndian)
    # Create a `Ref{}` pointing to type T, we'll unpack into that
    r = Ref{T}()
    packstrat = nfields(T) == 0 ? Default : packing_strategy(T)
    unsafe_unpack(io, T, r, endianness, packstrat)

    # De-reference `r` and return its unpacked contents
    return r[]
end

end # module
