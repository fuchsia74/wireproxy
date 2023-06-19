#!/bin/sh


# 定义一些变量
max_test=10  # 设置循环次数
total_test=0
fail_count=0
max_delay=8000 # 这里我们用毫秒来计算
total_delay=0
base_sleep_time=30  # 基础sleep时间
config_file=''



# 启动wireproxy程序的函数
start_wireproxy() {
    /usr/bin/wireproxy --config $1 &
    sleep 2
}

# 重启wireproxy程序的函数
restart_wireproxy() {
    pkill wireproxy
    start_wireproxy $1
}

# 检查wireproxy程序是否在运行
check_wireproxy() {
    pgrep wireproxy > /dev/null
    return $?
}

# 尝试获取一个锁定
get_lock() {
    lock_file="$1.lock"
    if (set -C; echo > "$lock_file") 2> /dev/null; then
        return 0
    else
        return 1
    fi
}

clean_up(){
    pkill wireproxy
    rm -rf $config_file.lock
    exit 0
}

if [ -z "${CONF_PATH}" ]; then
    echo "未设置必要的环境变量 CONF_PATH"
    exit 1
fi

# 依次尝试获取所有锁定
for i in $(ls ${CONF_PATH}/*.conf); do
    if get_lock $i; then
        config_file="$i"
        echo "Using config file $config_file"
        break
    fi
done

# 检查 config_file 是否被重新赋值
if [ -z "$config_file" ]; then
    echo "未找到可用的配置文件"
    exit 1
fi

# 主程序开始
# 启动wireproxy程序
restart_wireproxy $config_file

trap clean_up SIGTERM


while true
do
    sleep_time=$base_sleep_time  # 在每个内部循环开始时重置sleep时间
    while [ $total_test -lt $max_test ]
    do
        # 检查wireproxy程序是否在运行，如果不在运行则启动
        if ! check_wireproxy; then
            start_wireproxy $config_file
        fi

        # 测试目标url的可达性并获取http状态码和总延迟时间
        result=$(curl -o /dev/null -s -w "%{http_code},%{time_total}\n" -x socks5h://127.0.0.1:1088 http://www.msftconnecttest.com/connecttest.txt || echo "CURL_ERROR")
        
        # 计算总测试次数，无论测试结果如何
        total_test=$((total_test+1))
    
        if [ "$result" = "CURL_ERROR" ]; then
            # 如果curl命令失败，增加失败计数器并使用Karn算法来增加sleep_time
            fail_count=$((fail_count+1))
            #sleep_time=$((sleep_time*2))
            sleep $sleep_time
            continue  # 跳过当前循环剩下的部分
        else
            http_code=$(echo $result | cut -d ',' -f 1)
            delay=$(echo $result | cut -d ',' -f 2)

            # 将delay转换为毫秒
            delay_ms=$(awk "BEGIN {printf \"%d\", ($delay*1000)}")

            # 如果http状态码不等于200，则表示连接失败
            if [ "$http_code" != "200" ]; then
                fail_count=$((fail_count+1))
                # 使用Karn算法增加sleep时间
                #sleep_time=$((sleep_time*2))
            else
                # 计算总延迟
                total_delay=$((total_delay+delay_ms))
                sleep_time=$base_sleep_time
            fi
        fi
	echo "HEALTH: $fail_count/$total_test $delay"
        sleep $sleep_time
    done

    # 计算平均延迟
    avg_delay=$((total_delay/total_test))

    # 如果测试失败次数大于5次或平均延迟大于1500毫秒，则重启wireproxy程序
    if [ $fail_count -ge 5 ] || [ $avg_delay -gt $max_delay ]; then
	echo "RESTART: $fail_count/$total_test $avg_delay ms"
	new_endpoint=$(cat ${CONF_PATH}/result.csv | grep ",0.00%" | shuf -n1 | cut -d ',' -f 1)
	sed -i "s/^Endpoint = .*/Endpoint = $new_endpoint/" $config_file
        restart_wireproxy $config_file
    fi

    # 重置计数器
    total_test=0
    fail_count=0
    total_delay=0
done

