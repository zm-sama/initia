#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        apt-get install -y nodejs
        sudo apt install -y nodejs
        echo "Node.js 安装完成"
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        apt-get install -y npm
        sudo apt install -y npm
        echo "npm 安装完成"
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
        echo "pm2 安装完成"
    fi
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0
    else
        echo "Go 环境未安装，正在安装..."
        rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
        echo "Go 环境安装完成"
    fi
}

# 节点安装功能
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # 更新和安装必要的软件
    apt update && apt upgrade -y
    apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # 安装 Go
    check_go_installation

    # 安装所有二进制文件
    git clone https://github.com/initia-labs/initia
    cd initia
    git checkout v0.2.12
    make install
    initiad version

    # 配置initiad
    initiad init "Moniker" --chain-id initiation-1
    initiad config set client chain-id initiation-1

    # 获取初始文件和地址簿
    wget -O $HOME/.initia/config/genesis.json https://initia.s3.ap-southeast-1.amazonaws.com/initiation-1/genesis.json
    wget -O $HOME/.initia/config/addrbook.json https://rpc-initia-testnet.trusted-point.com/addrbook.json
    sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.15uinit,0.01uusdc\"|" $HOME/.initia/config/app.toml

    # 配置节点
    PEERS="40d3f977d97d3c02bd5835070cc139f289e774da@168.119.10.134:26313,841c6a4b2a3d5d59bb116cc549565c8a16b7fae1@23.88.49.233:26656,e6a35b95ec73e511ef352085cb300e257536e075@37.252.186.213:26656,2a574706e4a1eba0e5e46733c232849778faf93b@84.247.137.184:53456,ff9dbc6bb53227ef94dc75ab1ddcaeb2404e1b0b@178.170.47.171:26656,edcc2c7098c42ee348e50ac2242ff897f51405e9@65.109.34.205:36656,07632ab562028c3394ee8e78823069bfc8de7b4c@37.27.52.25:19656,028999a1696b45863ff84df12ebf2aebc5d40c2d@37.27.48.77:26656,140c332230ac19f118e5882deaf00906a1dba467@185.219.142.119:53456,1f6633bc18eb06b6c0cab97d72c585a6d7a207bc@65.109.59.22:25756,065f64fab28cb0d06a7841887d5b469ec58a0116@84.247.137.200:53456,767fdcfdb0998209834b929c59a2b57d474cc496@207.148.114.112:26656,093e1b89a498b6a8760ad2188fbda30a05e4f300@35.240.207.217:26656,12526b1e95e7ef07a3eb874465662885a586e095@95.216.78.111:26656"
    sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.initia/config/config.toml

    # 配置端口
    node_address="tcp://localhost:53457"
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:53458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:53457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:53460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:53456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":53466\"%" $HOME/.initia/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:53417\"%; s%^address = \":8080\"%address = \":53480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:53490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:53491\"%; s%:8545%:53445%; s%:8546%:53446%; s%:6065%:53465%" $HOME/.initia/config/app.toml
    echo "export initiad_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile

    # 配置预言机
    git clone https://github.com/skip-mev/slinky.git
    cd slinky

    # checkout proper version
    git checkout v0.4.3

    make build

    # 配置预言机启用
    sed -i -e 's/^enabled = "false"/enabled = "true"/' \
       -e 's/^oracle_address = ""/oracle_address = "127.0.0.1:8080"/' \
       -e 's/^client_timeout = "2s"/client_timeout = "500ms"/' \
       -e 's/^metrics_enabled = "false"/metrics_enabled = "false"/' $HOME/.initia/config/app.toml

    pm2 start initiad -- start && pm2 save && pm2 startup

    pm2 stop initiad

    # # 配置快照
    # sudo apt install lz4 -y
    # echo "配置快照"
    # echo "wget https://rpc-initia-testnet.trusted-point.com/latest_snapshot.tar.lz4 -O latest_snapshot.tar.lz4"
    # echo "initiad tendermint unsafe-reset-all --home $HOME/.initia --keep-addr-book"
    # echo "lz4 -d -c ./latest_snapshot.tar.lz4 | tar -xf - -C $HOME/.initia"
    # 配置快照
    sudo apt install lz4 -y
    curl -L http://95.216.228.91/initia_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.initia
    mv $HOME/.initia/priv_validator_state.json.backup $HOME/.initia/data/priv_validator_state.json

    echo "pm2 start ./build/slinky -- --oracle-config-path ./config/core/oracle.json --market-map-endpoint 0.0.0.0:53490"
    echo "pem2 restart initiad"

    echo '====================== 安装完成,请退出脚本后执行 source $HOME/.bash_profile 以加载环境变量==========================='
}

# 查看initia 服务状态
function check_service_status() {
    pm2 list
}

# initia 节点日志查询
function view_logs() {
    pm2 logs initiad
}

# 卸载节点功能
function uninstall_node() {
    echo "你确定要卸载initia 节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "开始卸载节点程序..."
            pm2 stop initiad && pm2 delete initiad
            rm -rf $HOME/.initiad && rm -rf $HOME/initia $(which initiad) && rm -rf $HOME/.initia
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 创建钱包
function add_wallet() {
    initiad keys add wallet
}

# 导入钱包
function import_wallet() {
    initiad keys add wallet --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    initiad query bank balances "$wallet_address" --node $initiad_RPC_PORT
}

# 查看节点同步状态
function check_sync_status() {
    initiad status --node $initiad_RPC_PORT | jq .sync_info
}

# 创建验证者
function add_validator() {
    read -p "请输入钱包名称: " wallet_name

    read -p "请输入验证者的名称: " validator_name

    read -p "请输入验证者详情（例如'区块链'）: " details


    initiad tx mstaking create-validator   --amount=1000000uinit   --pubkey=$(initiad tendermint show-validator)   --moniker=$validator_name   --chain-id=initiation-1   --commission-rate=0.05   --commission-max-rate=0.10   --commission-max-change-rate=0.01   --from=$wallet_name   --identity=""   --website=""   --details=""   --gas=2000000 --fees=300000uinit --node $initiad_RPC_PORT -y

}

# 给自己地址验证者质押
function delegate_self_validator() {
    read -p "请输入质押代币数量（1,2,3）InIt: " math
    read -p "请输入钱包名称: (默认名称wallet): " wallet_name
    initiad tx mstaking delegate $(initiad keys show wallet --bech val -a) ${math}000000uinit --from $wallet_name --chain-id initiation-1 --gas=2000000 --fees=300000uinit --node $initiad_RPC_PORT -y
}

function wallet_unjail() {
    read -p "请输入钱包名称: " wallet_name
    initiad tx slashing unjail --from $wallet_name --fees=10000amf --chain-id=initiation-1 --node $initiad_RPC_PORT
}

# 主菜单
function main() {
    while true; do
        clear
        echo "================================================"
        echo "**************<<Initia Node 部署>>**************"
        echo "** 硬件配置:CPU 4C，内存:16G, 硬盘:1T SSD       "
        echo "** 服务器系统：Ubuntu                           "
        echo "** !!!! 请检查是否符合以上配置要求 !!!          "
        echo "================================================"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 创建钱包"
        echo "3. 导入钱包"
        echo "4. 查看钱包地址余额"
        echo "5. 查看节点同步状态"
        echo "6. 查看当前服务状态"
        echo "7. 运行日志查询"
        echo "8. 卸载节点"
        echo "9. 创建验证者"
        echo "10. 质押"
        echo "11. 解押"
        echo "退出脚本，请按键盘ctrl c退出即可"
        read -p "请输入选项（1-11）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) add_wallet ;;
        3) import_wallet ;;
        4) check_balances ;;
        5) check_sync_status ;;
        6) check_service_status ;;
        7) view_logs ;;
        8) uninstall_node ;;
        9) add_validator ;;
        10) delegate_self_validator ;;
        11) wallet_unjail ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main
