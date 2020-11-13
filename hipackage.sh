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

        echo "Make $i hipackage"
        version="${sdk_name#*-}"
        target="${sdk_name%-*}"

        # Download/Update hipackage
        if [ ! -d "$sdk_dir/$version/$target/package/hipackage" ]; then
            git clone https://github.com/willdeark/hipackage.git $sdk_dir/$version/$target/package/hipackage
        fi

        # Make hipackage
        cd $sdk_dir/$version/$target
        make package/hipackage/frp/compile V=s
        make package/hipackage/hicloud/compile V=s
        make package/hipackage/jq/compile V=s

        exit 0
    done
}
download_sdk
printf "\nError: Can't found '$sdk_name' target. Please check available target list again!\n\n" && usage
