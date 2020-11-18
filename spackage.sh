#!/usr/bin/env bash
# set -e

work_dir="$PWD"
sdk_dir="sdk"
targets="ar71xx-1806 ramips-1806 ipq806x-qsdk53 mvebu-1907"

gl_inet_imagebuilder_url="https://github.com/gl-inet-builder"

usage() {
	cat <<-EOF
Usage: 
./download.sh [target]   # Download the appropriate SDK

All available target list:
    ar71xx-1806     # usb150/ar150/ar300m16/mifi/ar750/ar750s/x1200
    ramips-1806     # mt300n-v2/mt300a/mt300n/n300/vixmini
    ipq806x-qsdk53  # b1300/s1300
    mvebu-1907      # mv1000

EOF
	exit 0
}

[ -z "$1" ] && usage

sdk_name=$1

download_sdk() {
    for i in $targets; do
        [ "$i" != "$sdk_name" ] && continue

        echo "Make $i spackage"
        version="${sdk_name#*-}"
        target="${sdk_name%-*}"
        curpath="$(pwd)"

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

        # Download/Update spackage
        if [ ! -d "$sdk_dir/$version/$target/package/spackage" ]; then
            git clone http://34.92.252.49:6003/gx/spackage.git $sdk_dir/$version/$target/package/spackage
        else
            cd $sdk_dir/$version/$target/package/spackage
            git fetch --all && git reset --hard origin/master
            cd $curpath
        fi
        if [ ! -d "$sdk_dir/$version/$target/package/spackage" ]; then
            echo "Clone spackage fail"
            exit 0
        fi

        # Make spackage
        cd $sdk_dir/$version/$target
        make package/spackage/frp/compile V=s TARGET=$target
        make package/spackage/speedbox/compile V=s TARGET=$target
        make package/spackage/jq/compile V=s TARGET=$target
        cd $curpath

        exit 0
    done
}
download_sdk
printf "\nError: Can't found '$sdk_name' target. Please check available target list again!\n\n" && usage
