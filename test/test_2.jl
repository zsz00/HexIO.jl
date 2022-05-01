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
    buf = Hex("/dev/sda")   # linux
    dump!(buf, 0x00, 512)
    dump!(buf, 510, 2)

    seek(buf.hex, 0x01f0)
    flag = read(buf.hex, Int16)   # flag读不出来,是[]
    flag = [read(buf.hex, UInt8) for i =1:4]
    println(flag)

    return
    if flag == 0
    println(aa)

    open()  返回的是IOStream
    
    seekstart(buf)

    flag = read(buf.hex, Int16)   # IOStream  seek(buf.hex, 2)后read会有问题 

    unsafe_read(io, target, sz)
    # p_type_1 = {128:'active',0:'normal'}
    # p_type_2 = {15:'Extent',7:'NTFS',12:'FAT32',131:'Linux'}

    hex = Hex(raw"C:\Users\zsz61\.julia\packages\HexIO\dma1c\test\test.bin")
    dev = open("\\\\.\\PHYSICALDRIVE0")
    seek(dev, 2)
    read(dev, 2)

end








