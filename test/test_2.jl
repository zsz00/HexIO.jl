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
        if data.type_2 == 0
            continue
        end
        println("Partition : $data")
        println("id:$i,type:$(p_type_2[data.type_2]),start:$(data.off_1*512/1024/1024)MB,size:$(data.p_size*512/1024/1024/1024)GB")
    end
end

read_mbr()

#=
julia --project=/home/zhangyong/codes/HexIO.jl/Project.toml /home/zhangyong/codes/HexIO.jl/test/test_2.jl


=#
