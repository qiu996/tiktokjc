#!/bin/bash
shopt -s expand_aliases
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

# 初始化变量
proxy_mode=0
proxy_server=""
proxy_port=""
proxy_user=""
proxy_pass=""

while getopts ":I:" optname; do
    case "$optname" in
    "I")
        iface="$OPTARG"
        useNIC="--interface $iface"
        ;;
    ":")
        echo "Unknown error while processing options"
        exit 1
        ;;
    esac
done

checkOS(){
    ifCentOS=$(cat /etc/os-release | grep CentOS)
    if [ -n "$ifCentOS" ];then
        OS_Version=$(cat /etc/os-release | grep REDHAT_SUPPORT_PRODUCT_VERSION | cut -f2 -d'"')
        if [[ "$OS_Version" -lt "8" ]];then
            echo -e "${Font_Red}此脚本不支持CentOS${OS_Version},请升级至CentOS8或更换其他操作系统${Font_Suffix}"
            echo -e "${Font_Red}3秒后退出脚本...${Font_Suffix}"
            sleep 3
            exit 1
        fi
    fi        
}
checkOS

if [ -z "$iface" ]; then
    useNIC=""
fi

if ! mktemp -u --suffix=RRC &>/dev/null; then
    is_busybox=1
fi

UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"

# 配置代理选项
function configure_proxy() {
    echo -e "${Font_SkyBlue}请选择检测模式:${Font_Suffix}"
    echo -e "1. ${Font_Green}自动默认检测本机${Font_Suffix}"
    echo -e "2. ${Font_Yellow}自定义输入Socks5代理(有密码验证)${Font_Suffix}"
    
    read -p "请输入选项(1-2): " choice
    
    case $choice in
        1)
            proxy_mode=0
            echo -e "${Font_Green}已选择自动默认检测本机模式${Font_Suffix}"
            ;;
        2)
            proxy_mode=1
            read -p "请输入Socks5代理服务器地址: " proxy_server
            read -p "请输入Socks5代理服务器端口: " proxy_port
            read -p "请输入Socks5代理用户名: " proxy_user
            read -s -p "请输入Socks5代理密码: " proxy_pass
            echo
            echo -e "${Font_Green}已配置Socks5代理: ${proxy_user}@${proxy_server}:${proxy_port}${Font_Suffix}"
            ;;
        *)
            echo -e "${Font_Red}无效的选项，请重新运行脚本${Font_Suffix}"
            exit 1
            ;;
    esac
}

# 获取代理配置的curl参数
function get_proxy_params() {
    if [ $proxy_mode -eq 1 ]; then
        echo "--proxy socks5h://${proxy_user}:${proxy_pass}@${proxy_server}:${proxy_port}"
    else
        echo ""
    fi
}

CountRunTimes() {
    if [ "$is_busybox" == 1 ]; then
        count_file=$(mktemp)
    else
        count_file=$(mktemp --suffix=RRC)
    fi
    proxy_params=$(get_proxy_params)
    RunTimes=$(curl $useNIC $proxy_params -s --max-time 10 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Flmc999%2FTikTokCheck&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false" >"${count_file}")
    TodayRunTimes=$(cat "${count_file}" | tail -3 | head -n 1 | awk '{print $5}')
    TotalRunTimes=$(cat "${count_file}" | tail -3 | head -n 1 | awk '{print $7}')
}

function get_ip_info() {
    proxy_params=$(get_proxy_params)
    local_ipv4=$(curl $useNIC $proxy_params -4 -s --max-time 10 api64.ipify.org)
    local_ipv4_asterisk=$(awk -F"." '{print $1"."$2".*.*"}' <<<"${local_ipv4}")
    local_isp4=$(curl $useNIC $proxy_params -s -4 -A $UA_Browser --max-time 10 https://api.ip.sb/geoip/${local_ipv4} | grep organization | cut -f4 -d '"')
}

function MediaUnlockTest_Tiktok_Region() {
    echo -n -e " Tiktok Region:\t\t\c"
    proxy_params=$(get_proxy_params)
    local Ftmpresult=$(curl $useNIC $proxy_params --user-agent "${UA_Browser}" -s --max-time 10 "https://www.tiktok.com/")

    if [[ "$Ftmpresult" = "curl"* ]]; then
        echo -n -e "\r Tiktok Region:\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local FRegion=$(echo $Ftmpresult | grep '"region":' | sed 's/.*"region"//' | cut -f2 -d'"')
    if [ -n "$FRegion" ]; then
        echo -n -e "\r Tiktok Region:\t\t${Font_Green}【${FRegion}】${Font_Suffix}\n"
        return
    fi

    local STmpresult=$(curl $useNIC $proxy_params --user-agent "${UA_Browser}" -sL --max-time 10 -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-Encoding: gzip" -H "Accept-Language: en" "https://www.tiktok.com" | gunzip 2>/dev/null)
    local SRegion=$(echo $STmpresult | grep '"region":' | sed 's/.*"region"//' | cut -f2 -d'"')
    if [ -n "$SRegion" ]; then
        echo -n -e "\r Tiktok Region:\t\t${Font_Yellow}【${SRegion}】(可能为IDC IP)${Font_Suffix}\n"
        return
    else
        echo -n -e "\r Tiktok Region:\t\t${Font_Red}Failed${Font_Suffix}\n"
        return
    fi
}

function Heading() {
    if [ $proxy_mode -eq 1 ]; then
        echo -e " ${Font_SkyBlue}** 通过代理检测: ${proxy_user}@${proxy_server}:${proxy_port}${Font_Suffix} "
    else
        echo -e " ${Font_SkyBlue}** 您的网络为: ${local_isp4} (${local_ipv4_asterisk})${Font_Suffix} "
    fi
    echo "******************************************"
    echo ""
}

function Goodbye() {
    echo ""
    echo "******************************************"
    echo ""
    echo -e ""
    echo -e ""
    echo -e ""
    echo -e ""
    #echo -e "${Font_Yellow}检测脚本当天运行次数：${TodayRunTimes}; 共计运行次数：${TotalRunTimes} ${Font_Suffix}"
    echo -e ""
    echo -e "${Font_SkyBlue}【TikTok相关】${Font_Suffix}"
    echo -e "================================================"
    echo -e "${Font_Yellow}Residential IP TikTok解锁${Font_Suffix}"
    echo ""
    echo -e "${Font_Green}✅ ${Font_Suffix} ${Font_SkyBlue}各国家宽IP${Font_Suffix}"
    echo -e "${Font_Green}✅ ${Font_Suffix} ${Font_SkyBlue}一键配置${Font_Suffix}"
    echo -e "${Font_Green}✅ ${Font_Suffix} ${Font_SkyBlue}支持定制${Font_Suffix}"
    echo ""
    echo -e "${Font_Yellow}联系咨询: https://t.me/czgno${Font_Suffix}"
    echo -e "================================================"
    echo -e ""
    echo -e ""
    echo -e ""
    echo -e ""
}

clear

function ScriptTitle() {
    echo -e "${Font_SkyBlue}【Tiktok区域检测】${Font_Suffix}"
    echo -e "${Font_Green}BUG反馈或使用交流可加TG群组${Font_Suffix} ${Font_Yellow}https://t.me/tiktok_operate ${Font_Suffix}"
    echo ""
    echo -e " ** 测试时间: $(date)"
    echo ""
}

function RunScript() {
    configure_proxy
    ScriptTitle
    CountRunTimes
    get_ip_info
    Heading
    MediaUnlockTest_Tiktok_Region
    Goodbye
}

RunScript