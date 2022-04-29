using HexIO


struct MBR
    # BHBBHBII  16B
    id = 0      # 分区id号
    type_1 = "" # 分区状态
    type_2 = "" # 分区文件系统类型
    off_1 = 0   # 起始偏移
    p_size = 0  # 分区大小
end


function read_mbr()
    buf = Hex("\\\\.\\PHYSICALDRIVE0")   # within
    buf = Hex("/dev/sda1")   # linux
    dump!(buf, 0x00, 512)
    dump!(buf, 510, 2)

    seek(buf.hex, 0x01f0)
    flag = read(buf.hex, Int16)
    println(flag)

    return
    if flag == 0
    println(aa)

    seekstart(buf)
    seekstart(buf)

    # p_type_1 = {128:'active',0:'normal'}
    # p_type_2 = {15:'Extent',7:'NTFS',12:'FAT32',131:'Linux'}
end








