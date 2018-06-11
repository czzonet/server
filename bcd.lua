--file "bcd.lua"
--v1.1 2018-06-10:fix bug ---更正了bcd字符串转数字的混淆
--                add third---添加对象，现在是"18" 18 0x18 即bcd字符串，真正代表的值，bcd数三者之间的转化。
--最后的bcd数化为对应ascll字符（string.char or string.format）连接而成的字符串，称为二进制原始数据字符串，不属于这三者
--原始数据再转化十六进制字符串，不属于这三者


--请将十六进制BCD码转化为十进制再输入！
-- 如0x18，输入24，返回18
function bcd_num_to_value (bcd_num)
    return bcd_num-(math.modf(bcd_num/16))*6
end
-- 输入18，返回24，即0x18
function value_to_bcd_num (num)
    return (math.modf(num/10))*16 + (math.fmod(num,10))
end

-- 输入"18"，返回18
function bcd_str_to_value (bcd_str)
    return tonumber(bcd_str)
end
-- 输入18，返回"18"
function value_to_bcd_str (num)
    return tostring(math.modf(num/10))..tostring(math.fmod(num,10))
end

-- 如把"18"化为0x18，返回24
function bcd_str_to_bcd_num (bcd_str)
    return tonumber(bcd_str, 16)
end
-- 输入0x18=24 ，返回"18"
function bcd_num_to_bcd_str (num)
    string.format("%02X",num)
end
