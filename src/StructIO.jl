VERSION >= v"0.4.0-dev+6641" && __precompile__()
module StructIO

    using Base: @pure
    using Base.Meta
    export @struct, unpack, pack, fix_endian

    fix_endian(x,::Val{:NativeEndian}) = x
    if Base.ENDIAN_BOM == 0x01020304
        fix_endian(x,::Val{:BigEndian}) = x
        fix_endian(x,::Val{:LittleEndian}) = bsawp(x)
    else
        fix_endian(x,::Val{:BigEndian}) = bsawp(x)
        fix_endian(x,::Val{:LittleEndian}) = x
    end

    # Default alignof function
    @pure function alignof(T::DataType)
        nfields(T) == 0 && return nextpow2(sizeof(T))
        maximum(map(S->(isbits(S) ? alignof(S) : sizeof(Ptr{Void})),T.types))
    end

    round_up(offset, alignemnt) = offset +
        mod(alignemnt - mod(offset, alignemnt), alignemnt)

    @pure function sizeof_default(T::DataType)
        @assert nfields(T) != 0 && isbits(T)
        accum = 0
        for field in T.types
            round_up(accum, alignof(field))
            accum += sizeof(field)
        end
        accum
    end

    @pure function sizeof_packed(T::DataType)
        @assert nfields(T) != 0 && isbits(T)
        sum(map(x->sizeof(x), T.types))
    end

    # Generates methods for unpack!, pack!, and sizeof
    macro struct(typ, annotations...)
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
            push!(ret.args,
                :(Base.sizeof(T::Type{$typname}) = StructIO.sizeof_default(T)))
        else
            push!(ret.args,
                :(Base.sizeof(T::Type{$typname}) = StructIO.sizeof_default(T)))
        end
        push!(ret.args,
            :(StructIO.unpack(io::IO, T::Type{$typname}, endianness::Val) =
                StructIO.unpack(io, T, endianness, Val{$(quot(alignment))}())))
        esc(ret)
    end

    # This is temporary. I expect to be able to do this without a generated
    # function, but it would require a little more constant folding capability
    # in the compiler to make it efficient
    """
        Unpacks the struct `T` from an IO object, with the given data stream
        endianness and the given alignment. endianness defaults to the the hosts
        native endianness, while alignment default to whichever default
        alignment was specified using the struct macro.
    """
    @generated function unpack(io::IO, T::Type, endianness::Val, alignment::Val)
        offset = 0
        reached_offset = 0
        T = T.parameters[1]
        # bitstypes just get read (with endian fix)
        nfields(T) == 0 && return :(StructIO.fix_endian(read(io, T), endianness))
        ret = Expr(:block)
        cns = Expr(:call,T)
        alignment = alignment.parameters[1]
        for i = 1:nfields(T)
            fieldT = fieldtype(T,i)
            fieldsize = sizeof(fieldT)
            (alignment != :align_packed) &&
                (offset = round_up(offset, alignof(fieldT)))
            if reached_offset != offset
                push!(ret.args,:(skip(io,$(offset-reached_offset))))
            end
            offset = reached_offset = offset + fieldsize
            sym = symbol("field$i")
            push!(ret.args,:($sym = unpack(io,$fieldT,endianness)))
            push!(cns.args,sym)
        end
        push!(ret.args,cns)
        ret
    end
    unpack(io::IO, T::Type) = unpack(io, T, Val{:NativeEndian}())
    # This one gets overwritten by @struct
    unpack(io::IO, T::Type, endianness::Val) = unpack(io, T, endianness, Val{:align_default}())

end # module
