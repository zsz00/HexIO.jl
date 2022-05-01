## HexIO Example

### Example usage
```julia
julia> using HexIO

julia> @io struct TwoUInt64s
           x::UInt64
           y::UInt64
       end

julia> buf = IOBuffer(collect(UInt8(1):UInt8(16))); 

julia> seekstart(buf); unpack(buf, TwoUInt64s) # Default endianness depends on machine
TwoUInt64s(0x0807060504030201, 0x100f0e0d0c0b0a09)

julia> seekstart(buf); unpack(buf, TwoUInt64s, :BigEndian)
TwoUInt64s(0x0102030405060708, 0x090a0b0c0d0e0f10)

io = open("", "rb")
buffer = read(io, read_size)

```


Hex has same fuctions for editing and displaying data in binary files in
hexadecimal format.

### Synopsis

#### dump!(self::Hex, offset = 0, n::Int = -1)
Displays binary file data beginning at offset and ending at offset + n.
- offset defaults to 0
- n defaults to file size - n.

#### edit!(self::Hex, datastr::String, offset = 0)
Edits targeted binary file by overwriting data beginning at offset.
- offset defaults to 0
- datastr can be in ASCII or hexadecimal format (ie. "foobar" or "0x666f6f626172")

### Examples

### Complete File Hexdump

```julia
hex = Hex("test/test.bin")
dump!(hex, 0x00)
```
```
00000000 | 5D 00 00 80 66 6F 6F 62   61 72 FF FF FF 00 7F E1 |]...foobar......
00000010 | 90 E6 67 83 93 40 93 22   A0 1B AB 50 6E A1 93 54 |..g..@."...Pn..T
00000020 | 3A 7F FD A3 D9 C0 60 29   AF B6 94 96 3E AA 5C 38 |:.....`)....>.\8
00000030 | 1C 05 02 31 7D 74 72 0D   40 3C 22 DA EF FA CA 80 |...1}tr.@<".....
00000040 | DF F8 E2 7B CC 65 09 29   64 C3 15 DE E6 39 B7 7E |...{.e.)d....9.~
00000050 | D5 8C AA 91 F0 28 37 E1   5D AD C0 37 74 16 CE C1 |.....(7.]..7t...
00000060 | 75 94 1E EA DD 64 D6 B5   A1 2E 54 3D 62 4B 72 30 |u....d....T=bKr0
00000070 | 5A 35 B8 5D 42 A2 24 A1   C6 22 6A BE C6 58 07 E5 |Z5.]B.$.."j..X..
00000080 | 4F F1 E3 FC 53 14 70 AA   AE 58 FA E3 D8 C4 3A DB |O...S.p..X....:.
00000090 | D2 81 CF 99 24 10 4C C1   53 76 98 BC 16 E9 C2 7E |....$.L.Sv.....~
000000A0 | 2C 6F 23 D6 F7 32 AB 81   7E 74 FD B6 FE B2 E7 15 |,o#..2..~t......
000000B0 | 83 7D 45 96 44 A8 D9 CF   B2 B8 AD 37 73 0E 15 AD |.}E.D......7s...
and so on...
```
### Chunk Hexdump

Dump 16 bytes beginning at offset 0x04
```julia
hex = Hex("test.bin")
dump!(hex, 0x04, 16)

00000004 | 66 6F 6F 62 61 72 FF FF   FF 00 7F E1 90 E6 67 83 |foobar........g.

dump!(hex.hex, 0x04, 16)

00000004 | 66 6F 6F 62 61 72 FF FF   FF 00 7F E1 90 E6 67 83 |foobar........g.
```

----

## Parse the MBR of the disk


```julia
using HexIO

@io struct MBR
    # BHBBHBII  16B
    type_1::UInt8 # 分区状态
    _1::UInt16
    _2::UInt8      # 
    type_2::UInt8 # 分区文件系统类型
    _3::UInt16   # xx
    _4::UInt8  # xx
    off_1::UInt32  # 起始偏移
    p_size::UInt32  # 分区大小
end align_packed

function read_mbr()
    # buf = Hex("\\\\.\\PHYSICALDRIVE0")  # win
    buf = Hex("/dev/sda")   # linux
    println("Data from the first partition of the disk:")
    dump!(buf.hex, 0, 512)

    seek(buf.hex, 510)
    flag = read(buf.hex, 2)   # win10里flag读不出来,是[]

    if flag == [0x55, 0xaa]
        endianness = :LittleEndian 
    else
        endianness = :BigEndian
    end
    
    p_type_1 = Dict(128=>"active",0=>"normal")
    p_type_2 = Dict(15=>"Extent",7=>"NTFS",12=>"FAT32",131=>"Linux")

    seek(buf.hex, 446)
    println("Parses disk partition information:")
    for i in 1:4
        buf_1 = read(buf.hex, 16)   # 每次读后,指针都会移动到当前位置
        # dump!(buf.hex, 0, 16)
        data = unpack(IOBuffer(buf_1), MBR, endianness)
        println("Partition : $data")
        if data.type_2 == 0
            continue
        end
        println("id:$i,type:$(p_type_2[data.type_2]),start:$(data.off_1*512/1024/1024)MB,size:$(data.p_size*512/1024/1024/1024)GB")
    end
end

read_mbr()
```

```
Data from the first partition of the disk:
00000000 | EB 63 90 10 8E D0 BC 00   B0 B8 00 00 8E D8 8E C0 |.c..............
00000010 | FB BE 00 7C BF 00 06 B9   00 02 F3 A4 EA 21 06 00 |...|.........!..
00000020 | 00 BE BE 07 38 04 75 0B   83 C6 10 81 FE FE 07 75 |....8.u........u
00000030 | F3 EB 16 B4 02 B0 01 BB   00 7C B2 80 8A 74 01 8B |.........|...t..
00000040 | 4C 02 CD 13 EA 00 7C 00   00 EB FE 00 00 00 00 00 |L.....|.........
00000050 | 00 00 00 00 00 00 00 00   00 00 00 80 01 00 00 00 |................
00000060 | 00 00 00 00 FF FA 90 90   F6 C2 80 74 05 F6 C2 70 |...........t...p
00000070 | 74 02 B2 80 EA 79 7C 00   00 31 C0 8E D8 8E D0 BC |t....y|..1......
00000080 | 00 20 FB A0 64 7C 3C FF   74 02 88 C2 52 BB 17 04 |. ..d|<.t...R...
00000090 | F6 07 03 74 06 BE 88 7D   E8 17 01 BE 05 7C B4 41 |...t...}.....|.A
000000A0 | BB AA 55 CD 13 5A 52 72   3D 81 FB 55 AA 75 37 83 |..U..ZRr=..U.u7.
000000B0 | E1 01 74 32 31 C0 89 44   04 40 88 44 FF 89 44 02 |..t21..D.@.D..D.
000000C0 | C7 04 10 00 66 8B 1E 5C   7C 66 89 5C 08 66 8B 1E |....f..\|f.\.f..
000000D0 | 60 7C 66 89 5C 0C C7 44   06 00 70 B4 42 CD 13 72 |`|f.\..D..p.B..r
000000E0 | 05 BB 00 70 EB 76 B4 08   CD 13 73 0D 5A 84 D2 0F |...p.v....s.Z...
000000F0 | 83 D0 00 BE 93 7D E9 82   00 66 0F B6 C6 88 64 FF |.....}...f....d.
00000100 | 40 66 89 44 04 0F B6 D1   C1 E2 02 88 E8 88 F4 40 |@f.D...........@
00000110 | 89 44 08 0F B6 C2 C0 E8   02 66 89 04 66 A1 60 7C |.D.......f..f.`|
00000120 | 66 09 C0 75 4E 66 A1 5C   7C 66 31 D2 66 F7 34 88 |f..uNf.\|f1.f.4.
00000130 | D1 31 D2 66 F7 74 04 3B   44 08 7D 37 FE C1 88 C5 |.1.f.t.;D.}7....
00000140 | 30 C0 C1 E8 02 08 C1 88   D0 5A 88 C6 BB 00 70 8E |0........Z....p.
00000150 | C3 31 DB B8 01 02 CD 13   72 1E 8C C3 60 1E B9 00 |.1......r...`...
00000160 | 01 8E DB 31 F6 BF 00 80   8E C6 FC F3 A5 1F 61 FF |...1..........a.
00000170 | 26 5A 7C BE 8E 7D EB 03   BE 9D 7D E8 34 00 BE A2 |&Z|..}....}.4...
00000180 | 7D E8 2E 00 CD 18 EB FE   47 52 55 42 20 00 47 65 |}.......GRUB .Ge
00000190 | 6F 6D 00 48 61 72 64 20   44 69 73 6B 00 52 65 61 |om.Hard Disk.Rea
000001A0 | 64 00 20 45 72 72 6F 72   0D 0A 00 BB 01 00 B4 0E |d. Error........
000001B0 | CD 10 AC 3C 00 75 F4 C3   55 D2 A1 3F 00 00 80 20 |...<.u..U..?... 
000001C0 | 21 00 83 F7 DC 7A 00 08   00 00 DF 3F C3 37 00 00 |!....z.....?.7..
000001D0 | 00 00 00 00 00 00 00 00   00 00 00 00 00 00 00 00 |................
000001E0 | 00 00 00 00 00 00 00 00   00 00 00 00 00 00 00 00 |................
000001F0 | 00 00 00 00 00 00 00 00   00 00 00 00 00 00 55 AA |..............U.

Parses disk partition information:
Partition : MBR(0x80, 0x2120, 0x00, 0x83, 0xdcf7, 0x7a, 0x00000800, 0x37c33fdf)
id:1,type:Linux,start:1.0MB,size:446.1015467643738GB

```



