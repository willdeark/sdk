#!/usr/bin/env bash
# set -e

work_dir="$PWD"
sdk_dir="sdk"
targets="ar71xx-1806 ramips-1806 ipq806x-qsdk53 mvebu-1907"

curpath="$(pwd)"
serverip=""
serverdomain=""

gl_inet_imagebuilder_url="https://github.com/gl-inet-builder"


compile_start() {
    utilpath="${sdk_dir}/spackage/speedbox/files/_common/etc/init.d/speedbox_utils"

    # Download/Update spackage
    if [ ! -d "$sdk_dir/spackage" ]; then
        git clone ssh://git@34.92.252.49:6005/gx/spackage.git $sdk_dir/spackage
    else
        cd $sdk_dir/spackage
        git fetch --all && git reset --hard origin/master
        cd $curpath
    fi
    if [ ! -f "$utilpath" ]; then
        echo "Clone spackage fail"
        exit 0
    fi

    serverip_=`grep -E -o "FRPC_SERVER_ADDR\=\"(.*?)\"" ${utilpath} | head -1 | awk -F "=\"" '{print $2}'  | awk -F "\"" '{print $1}'`
    serverdomain_=`grep -E -o "FRPC_SERVER_DOMAIN\=\"(.*?)\"" ${utilpath} | head -1 | awk -F "=\"" '{print $2}'  | awk -F "\"" '{print $1}'`

    read -rp "调度中心地址（默认:${serverip_}）：" serverip
    [[ -z ${serverip} ]] && serverip="$serverip_"
    read -rp "穿透绑定域名（默认:${serverdomain_}）：" serverdomain
    [[ -z ${serverdomain} ]] && serverdomain="$serverdomain_"

    if [[ "$serverdomain" != *"*"* ]]; then
        echo "穿透绑定域名格式错误"
        exit 0
    fi

    sed -i "/PUBLISH_DEVICE_URL=/c PUBLISH_DEVICE_URL=\"http:\/\/${serverip}:6006\" #调度中心域名（建议使用IP地址）" ${utilpath}
    sed -i "/FRPC_SERVER_ADDR=/c FRPC_SERVER_ADDR=\"${serverip}\" #穿透服务端IP" ${utilpath}
    sed -i "/FRPC_SERVER_DOMAIN=/c FRPC_SERVER_DOMAIN=\"${serverdomain}\" #穿透绑定域名后缀" ${utilpath}

    for sdk_name in $targets; do
        echo "Make $sdk_name spackage"
        version="${sdk_name#*-}"
        target="${sdk_name%-*}"

        # Download/Update OpenWrt SDK
        if [ ! -d "$sdk_dir/$version/$target" ]; then
            git clone $gl_inet_imagebuilder_url/openwrt-sdk-$sdk_name.git $sdk_dir/$version/$target
            [ "$target" != "ipq806x" ] && {
               pushd $sdk_dir/$version/$target > /dev/null
               ./scripts/feeds update -f
               ./scripts/feeds install uci curl libubus libubox libiwinfo libsqlite3 mqtt fcgi #install default depends packages
               make defconfig
               popd > /dev/null
               printf "\nUse 'builder.sh script to compile all your packages.\nRun './builder.sh' to get more help.\n\n"
            }
        else
            pushd $sdk_dir/$version/$target > /dev/null
            git pull
            popd > /dev/null
        fi

        # Download jq-1.5.tar.gz
        if [ "$target" == "ipq806x" ]; then
            if [ ! -f "$sdk_dir/$version/$target/dl/jq-1.5.tar.gz" ]; then
                wget -P "$sdk_dir/$version/$target/dl/" https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz
            fi
        fi

        # copy spackage
        mkdir -p $sdk_dir/$version/$target/package
        /bin/cp -rf $sdk_dir/spackage $sdk_dir/$version/$target/package

        # Delete old
        rm -rf $sdk_dir/$version/$target/bin/packages/*/base/frp* && rm -rf ../imagebuilder/glinet/$target/frp*
        rm -rf $sdk_dir/$version/$target/bin/packages/*/base/jq* && rm -rf ../imagebuilder/glinet/$target/jq*
        rm -rf $sdk_dir/$version/$target/bin/packages/*/base/speedbox* && rm -rf ../imagebuilder/glinet/$target/speedbox*

        # Make spackage
        cd $sdk_dir/$version/$target
        make package/spackage/frp/compile V=s TARGET=$target
        make package/spackage/speedbox/compile V=s TARGET=$target
        make package/spackage/jq/compile V=s TARGET=$target
        cd $curpath

        # Copy to imagebuilder
        /bin/cp -rf $sdk_dir/$version/$target/bin/packages/*/base/frp* ../imagebuilder/glinet/$target
        /bin/cp -rf $sdk_dir/$version/$target/bin/packages/*/base/jq* ../imagebuilder/glinet/$target
        /bin/cp -rf $sdk_dir/$version/$target/bin/packages/*/base/speedbox* ../imagebuilder/glinet/$target
    done
}

compile_image() {
    cd ../imagebuilder/
    rm -rf ./bin
    ./gl_image -p usb150
    ./gl_image -p ar750s
    ./gl_image -p mt300n-v2
    ./gl_image -p b1300
    ./gl_image -p mv1000-emmc
    ./gl_image -p mifi
    cd $curpath
    mkdir -p ./bin
    rm -rf ./bin/$serverip
    /bin/cp -rf ../imagebuilder/bin ./bin/$serverip
}

compile_start
compile_image