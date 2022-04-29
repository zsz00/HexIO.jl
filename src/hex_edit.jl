
mutable struct Hex
    hex::IO
    _size::Int
    _offset::UInt64
end # type Hex

"""
    Hex(filename::AbstractString, _offset::Int=0)

"""
function Hex(filename::AbstractString, _offset::Int=0)
    hex        = open(filename, "r+")
    _size  =  filename[1:4]=="\\\\.\\" ? 0 : filesize(filename)
    println("_size:", _size)
    Hex(hex, _size, _offset)
end  # constructor Hex

"""
    Hex(io::IO, _offset::Int=0)

"""
function Hex(io::IO, _offset::Int=0)
    hex        = io
    _size  =  stat(io).size
    println("_size:", _size)
    Hex(hex, _size, _offset)
end  # constructor Hex

"""
    dump_line(s::Hex, line::Array{UInt8})

displays data in hex format.
"""
function dump_line(s::Hex, line::Array{UInt8})
    llen = length(line)
    plen = llen % 16
    println("=======", llen)
    print("$(uppercase(string(s._offset, base=16, pad=8))) | ")
    n = 0
    for byte in line
        # space every 8 bytes
        if n == 8
            print("  ")
        end
        print("$(uppercase(string(byte, base=16, pad=2))) ")
        n = n + 1
    end
    # line up ascii on the last line of dumps
    # if plen != 0
    #     while n < 16
    #         if n % 4 == 0
    #             print("  ")
    #         end
    #         print(" ")
    #         n = n + 1
    #     end
    # end
    print("|")
    # print ascii
    n = 0
    for byte in line
        if byte < 32 || byte > 126
            print(".")
        else
            print(Char(byte))
        end
        n = n + 1
    end
    print("\n")
    s._offset = s._offset + llen
end # function dump_line

"""
    dump_buffer(s::Hex, buffer::Array{UInt8})

helper for dump!; iterates buffer and displays data by tasking helper dump_line.
"""
function dump_buffer(s::Hex, buffer::Array{UInt8})
    blen = length(buffer)
    llen = 16
    idx  = 1
    println("-------------------------- $blen, $(s._offset)")
    while idx < blen
        if idx + 16 > blen
            llen = blen - idx + 1
        end
        print("**********", llen, blen)
        dump_line(s, buffer[idx:(idx + llen - 1)])
        idx = idx + llen
    end
end # function dump_buffer

"""
    dump!(s::Hex, start=nothing, n=nothing)

display data chunk of n size beginning at offset
"""
function dump!(s::Hex, start=nothing, n=nothing)
    if n === nothing
        n = s._size
    end

    if start !== nothing
        s._offset = convert(UInt64, start)
    end
    seek(s.hex, s._offset)

    read_size = 1024
    idx   = 0
    total = 0
    while total < n
        if idx + 1024 > n
            read_size = n - idx
        end
        println("aaaaaaaaaa: $read_size, $(s._offset)")
        buffer = read(s.hex, read_size)
        println("bbbbbbbb: $buffer")
        dump_buffer(s, buffer)
        total = total + read_size
    end
end # function dump!

dump!(buf::IO, start=nothing, n=nothing) = dump!(Hex(buf, start), start, n)


"""
    hex2bin(rawstr::AbstractString)

converts ASCII string or hexadecimal string to binary byte array
"""
function hex2bin(rawstr::AbstractString)
    if (match(r"^0x[0-9a-fA-F]+", rawstr) === nothing)  # If it is not a hexadecimal string
        return Array{UInt8}(rawstr)
    end
    m = match(r"0x([0-9a-fA-F]+)", rawstr)
    len = length(m.captures[1])
    if len % 2 != 0
        error("hex string length must be divisible by 2")
    end
    hex2bytes(ascii(m.captures[1]))
end # function hex2bin

"""
    edit!(s::Hex, datastr::AbstractString, start=nothing)

edit binary file.
"""
function edit!(s::Hex, datastr::AbstractString, start=nothing)
    if start !== nothing
        s._offset = convert(UInt64, start)
    end

    databytes = hex2bin(datastr)
    if s._offset + length(databytes) > s._size
        error("cannot write past end of file")
    end
    seek(s.hex, s._offset)
    write(s.hex, databytes)
end # function edit!

"""
    find!(s::Hex, sigstr::AbstractString, start=nothing)
    
search for binary signature and return the offset or nothing; 
modify s._offset to point to beginning of located signature
"""
function find!(s::Hex, sigstr::AbstractString, start=nothing)
    if start !== nothing
        s._offset = convert(UInt64, start)
    else
        s._offset = 0
    end
    sigbytes = hex2bin(sigstr)
    seek(s.hex, s._offset)
    siglen = length(sigbytes)
    if siglen > s._size
        error("signature length exceeds file size")
    end

    # read to siglen
    total = 0
    buffer = read(s.hex, siglen)
    if buffer == sigbytes
        return s._offset = convert(UInt64, total - siglen)
    end
    total = total + siglen
    
    # read byte by byte
    idx = 0
    while total < s._size
        if idx + siglen > s._size
             break
        end
        byte = read(s.hex, 1)
        total = total + 1
        buffer = append!(buffer[2:end], byte)
        if buffer == sigbytes
            return s._offset = convert(UInt64, total - siglen)
        end
    end

    nothing
end # function find!
