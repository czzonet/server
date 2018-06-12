-- --TCP server

-- TODO 把数据帧转化为十六进制字符串输出到日志

-- including
dofile("/media/sf_vbox_shared/server/bcd.lua")

-- 数据帧，表结构，把接收到的分段数据帧依次保存，最后连接一下即可得到数据。
-- 正常数据帧
local frame_data = {}
-- 已接收到的异常数据帧
local frame_partical = {}

--启动TCP server数据接收
local sock = assert(ngx.req.socket(true))
sock:settimeout(15000)    -- 15s time

function log_add (category ,message)
    local log_str = string.format("[%s]%s", category, message)
    ngx.log(ngx.ERR, log_str)
end

-- 接收并进行对应记录
function receive_length_of_data (length)
    local line,err,partical = sock:receive(length)
    if not line then
        table.insert(frame_partical, partical)
        log_add("err", "receive:no length of data:"..length)
        return false
    else
        table.insert(frame_data, line)
        return line
    end
end

-- 处理数据头，注意一个一个字节判断，避免等待过长字节而阻塞超时。
function frame_head_process ()
    -- 0xFFFA，即255 250
    -- TODO 测试错误数据帧的日志记录情况
    log_add("msg","========")
    local temp1 = receive_length_of_data(1)
    if temp1 == false then
        return false
    end
    if(string.byte(temp1) ~= 255) then
        return false
    end

    local temp2 = receive_length_of_data(1)
    if temp2 == false then
        return false
    end
    if(string.byte(temp2) ~= 250) then
        return false
    end

    return true
end

--接收数据帧并根据协议解析结构
function frame_receive_process ()
    -- 判断数据帧头部
    if frame_head_process() then
        -- 头部正确，继续接收剩下的帧前半部分
        -- 固定前半部分8字节，除去已经接收的数据头2字节
        local frame_data_first_part = receive_length_of_data(8-2)
        if frame_data_first_part == false then
            return false
        end

        -- 解析长度，接收剩下部分
        local frame_len = 0
        frame_len = (string.byte(frame_data_first_part,2) * 256) + string.byte(frame_data_first_part,3)
        log_add("msg", string.format("length of the last part frame is %d,total length of frame is %d",frame_len ,frame_len + 5))
        -- 除去固定部分
        local frame_data_last_part = receive_length_of_data(frame_len-3)
        if frame_data_last_part == false then
            return false
        end

        -- 连接数据帧
        local frame_data_entire = table.concat(frame_data)
        -- 化为str进行日志记录
        local frame_data_entire_hex_str_table = {}
        for i=1,#frame_data_entire do
            table.insert(frame_data_entire_hex_str_table,string.format("%02X",string.byte(frame_data_entire,i)))
        end
        local frame_data_entire_hex_str_entire = table.concat(frame_data_entire_hex_str_table)
        log_add("msg", string.format("the entire frame data is %s.", frame_data_entire_hex_str_entire))

        -- 进行校验计算 TODO 有错误，总数据帧还没有出来
        local cal_sum = 0
        local assert_sum = string.byte(frame_data_entire,#frame_data_entire)
        for i = 4, (#frame_data_entire)-1 do
            cal_sum = cal_sum +string.byte(frame_data_entire,i)
        end
        cal_sum = math.fmod(cal_sum, 256)

        if (cal_sum ~= assert_sum) then
            log_add("err",string.format("check sum failed:assart %d,but cal to %d", assert_sum, cal_sum))
            return false
        else
            log_add("msg", "receive:check sum ok, data receive complete.")
            return true
        end
    else
        return false
    end
end

--计算校验和 转化为数字进行计算，最后转回字符
function check_sum_process(data)
    local cal_sum = 0
    for i=4,#data do
        cal_sum = cal_sum +string.byte(data,i)
    end
    return string.char(math.fmod(cal_sum, 256))
end

-- 响应数据帧
function frame_respond_process ()
    -- 连接数据帧
    local frame_data_entire = table.concat(frame_data)
    --判断命令字
    if (string.byte(frame_data_entire,6) == 1) then
        log_add("msg","start respond.order type is 1.")
        --命令1 登录
        -- 构造响应体
        local login_result =  string.format("%c",1)
        -- 得到日期
        local d_time =os.date("0%w%y%m%d%H%M%S")
        local d_time_table = {}
        -- i = 1 to 7
        for i=1,(#d_time)/2 do
            table.insert(d_time_table,string.char(bcd_str_to_bcd_num(string.sub(d_time,2*i-1,2*i))))
        end
        local d_time_entire = table.concat(d_time_table)

        local power_entire = value_to_data_str(2, 4)
        -- 长度固定的是(2+1+2+1+2)+(1+7+4)+1-(2+1+2)=16
        local frame_respond_first_part = string.sub(frame_data_entire,1,3)..value_to_data_str(16, 2)..string.sub(frame_data_entire,6,8)
        local frame_respond_last_part = login_result..d_time_entire..power_entire
        local frame_respond_entire = frame_respond_first_part..frame_respond_last_part
        local frame_respond_final = frame_respond_entire..check_sum_process(frame_respond_entire)
        -- 化为str进行日志记录
        log_add("msg","frame_respond_final is :"..data_str_to_hex_str(frame_respond_final))

        --发送
        sock:settimeout(1000)
        local bytes, err = sock:send(frame_respond_final)
    end

    --
    if (string.byte(frame_data_entire,6) == 2) then
        -- 命令二 采集
        log_add("msg","start respond.order type is 1.")

        local frame_respond_first_part = string.sub(frame_data_entire,1,3)..value_to_data_str(5, 2)..string.sub(frame_data_entire,6,8)
        local frame_respond_last_part = value_to_data_str(1, 1)
        local frame_respond_entire = frame_respond_first_part..frame_respond_last_part
        local frame_respond_final = frame_respond_entire..check_sum_process(frame_respond_entire)
        -- 化为str进行日志记录
        log_add("msg","frame_respond_final is :"..data_str_to_hex_str(frame_respond_final))

        --发送
        sock:settimeout(1000)
        local bytes, err = sock:send(frame_respond_final)
    end
end

-- 即将真值化为指定字节长度原始数据字符串
function value_to_data_str (value, width)
    --化十六进制字符串，长度扩充两倍
    local format_str = string.format("%s0%dX","%",2*width)
    local hex_str = string.format(format_str,value)
    local data_str_table = {}
    --两个一组字符压缩回原始数据字符串
    for i=1,(#hex_str)/2 do
        table.insert(data_str_table, string.char(tonumber(string.sub(hex_str,2*i-1,2*i), 16)))
    end
    local data_str_entire = table.concat(data_str_table)
    return data_str_entire
end

--TODO 把原始字符串转化为真值

-- 将原始数据字符串化为十六进制字符串，以便于显示阅读，或者日志记录
function data_str_to_hex_str (data_str)
    local hex_str_table = {}
    for i=1,#data_str do
        table.insert(hex_str_table, string.format("%02X", string.byte(data_str, i)))
    end
    local hex_str_entire = table.concat(hex_str_table)
    return hex_str_entire
end

-- main process start
-- 接收数据帧，包括判断，接收，校验三步，并记录正确数据帧
if frame_receive_process() == false then
    --接收失败 记录错误帧
    log_add("err", string.format("partical frame:%s",table.concat(frame_partical)))
else
    -- 接收成功，进入对应命令字的不同处理程序
    frame_respond_process()
end
