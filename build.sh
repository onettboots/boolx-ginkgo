#!/bin/bash 

KDIR="${PWD}"
KERNEL=out/arch/arm64/boot/Image.gz-dtb
DTBO=out/arch/arm64/boot/dtbo.img
OUT_IMAGE="out/arch/arm64/boot/Image.gz-dtb"
DTBO_TMP="out/dtbotmp"
OUT_DTBO="$DTBO_TMP/dtbo.img"
OUT_DTB_GINKGO="out/arch/arm64/boot/dts/xiaomi/qcom-base/trinket.dtb"
OUT_DTB_LAUREL="out/arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-base.dtb"
OUT_DTB="$OUT_DTB_GINKGO"
IN_DTBO_GINKGO="out/arch/arm64/boot/dts/xiaomi/ginkgo-trinket-overlay.dtbo"
IN_DTBO_LAUREL="out/arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-overlay.dtbo"
REPACK_DIR=$HOME/AnyKernel3ginkgo

rm .version > /dev/null 2>&1
rm build.log > /dev/null 2>&1
rm $KERNEL > /dev/null 2>&1
rm $REPACK_DIR/dtb-ginkgo > /dev/null 2>&1
rm $REPACK_DIR/dtb-laurel_sprout > /dev/null 2>&1
rm $REPACK_DIR/dtbo-ginkgo.img > /dev/null 2>&1
rm $REPACK_DIR/dtbo-ginkgo.img > /dev/null 2>&1

# Bash Color
yellow='\033[01;33m'
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

# Help
HELP=$(cat <<EOF
------------------------------------------
            Boolx Kernel Build
==========================================
  --clean  | -c : Clean build
  --ksun   | -k : Build KSU Next and SUSFS
  --xksu   | -x : Build XXKSU and SUSFS
  --suki   | -s : Build SUKISU and SUSFS
  --normal | -n : Build without KSU stuffs
------------------------------------------
EOF
)

clear
echo -e "${green}"
echo "$HELP"
echo -e "${restore}"

# Resources
export ARCH=arm64
export PATH="$HOME/toolchains/boolx-clang/bin/:$PATH"
export CC=$HOME/toolchains/boolx-clang/bin/clang
export LC_ALL=C
export USE_CCACHE=1
export CCACHE_EXEC=$(command -v ccache)
export THINLTO_CACHE_DIR=/home/onettboots/toolchains/thincache
#export CCACHE_DIR="$HOME/toolchains/boolx_ccache" #localbuild
ccache -M 10G
#export DTC_EXT=dtc

# Variables
TARGET_IMAGE="Image.gz-dtb"
cpus=`expr $(nproc --all)`
objdir="${KDIR}/out"
BASE_DEFCONFIG="boolx_defconfig"
BASE_DEFCONFIG_PATH="arch/arm64/configs/$BASE_DEFCONFIG"
CFGOUT=$KDIR/out/.config
VER="V1.0-Serepet"
KDIR=`pwd`
ZIP_MOVE=$HOME/Boolx
BASE_AK_VER="Bool-X-Trinket-"
DATE=`date +"%Y%m%d-%H%M"`
AK_VER="$BASE_AK_VER$VER"
ZIP_NAME="$AK_VER"-"$DATE"
TOOLCHAINS=$HOME/toolchains/boolx-clang
SAVEHERE=$HOME/toolchains
CONFIG=out/.config
upl=$KDIR/upl.sh
KER_VER=$(grep -oP '(?<=VERSION = )\d+|(?<=PATCHLEVEL = )\d+|(?<=SUBLEVEL = )\d+' Makefile | paste -sd '.')

# functions
function cook() {
                PATH=${CLANG_BIN}:${PATH} \
                make -s -j${cpus} \
                LLVM=1 \
                LLVM_IAS=1 \
                CC="ccache clang" \
                CROSS_COMPILE="aarch64-linux-gnu-" \
                CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
                O="${objdir}" ${1} \
                KBUILD_BUILD_USER="OnettBoots" \
                KBUILD_BUILD_HOST="OpenELA"
}

function build() {
	export CCACHE_COMPILERCHECK=content
        make -j$(nproc --all) O=out \
        ARCH=arm64 \
        CC="ccache clang" \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        LLVM=1 \
        LLVM_IAS=1 \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE="aarch64-linux-gnu-"
}

function progress() {
    local target_file="logs.txt"
    local bar_length=50
    local percent=0
    local count=0
    local total_lines=4745

    while [ ! -f "$target_file" ]; do
        sleep 0.1
    done

    if [ "$IS_CLEAN" = true ]; then
        total_lines=4745
    else
        total_lines=1500
    fi

    while true; do
        count=$(wc -l < "$target_file" 2>/dev/null || echo 0)

        # 1. Cek jika build selesai
        if grep -q "CAT     arch/arm64/boot/Image.gz-dtb" "$target_file" 2>/dev/null; then
            percent=100
            filled=$bar_length
            empty=0

            printf "\r\033[KBuilding: [%-${bar_length}s] %3d%%\n" \
                "$(printf '#%.0s' $(seq 1 $filled))" \
                "$percent"
            
            #echo -e "\n${green}==> Done build!${restore}"
            break
        fi

        percent=$(( count * 100 / total_lines ))
        if (( count > total_lines )) && (( percent < 99 )); then
            total_lines=$(( total_lines + 500 ))
        fi

        (( percent > 99 )) && percent=99
        (( percent < 1 )) && percent=1

        filled=$(( percent * bar_length / 100 ))
        empty=$(( bar_length - filled ))

        printf "\r\033[KBuilding: [%-${bar_length}s] %3d%%" \
            "$(printf '#%.0s' $(seq 1 $filled))$(printf '.%.0s' $(seq 1 $empty))" \
            "$percent"

        sleep 0.2
    done
}

dtbo_build() {
    echo -e ""
    mkdir -p "$DTBO_TMP"
    local IN_DTBO=""
    python3 "$KDIR/scripts/dtc/libfdt/mkdtboimg.py" create "$DTBO_TMP/dtbo-ginkgo.img" --custom0=0x00000000 --custom1=0x00000000 --page_size=4096 "$IN_DTBO_GINKGO"
    python3 "$KDIR/scripts/dtc/libfdt/mkdtboimg.py" create "$DTBO_TMP/dtbo-laurel_sprout.img" --custom0=0x00000000 --custom1=0x00000000 --page_size=4096 "$IN_DTBO_LAUREL"
    OUT_DTBO="$DTBO_TMP/dtbo-ginkgo.img"
}

function create_out {
		echo
		git clone https://github.com/onettboots/boolx_anykernel.git -b ginkgo $REPACK_DIR && mkdir $ZIP_MOVE
}

function make_boot {
	cp $KERNEL $REPACK_DIR
        cp $DTBO_TMP/dtbo-ginkgo.img $REPACK_DIR
        cp $DTBO_TMP/dtbo-laurel_sprout.img $REPACK_DIR
        cp $OUT_DTB_GINKGO $REPACK_DIR/dtb-ginkgo
        cp $OUT_DTB_LAUREL $REPACK_DIR/dtb-laurel_sprout
}
function check_ksuver {
		KSU_VERSION=10200
		KSU_GIT_VERSION=$(cd $KDIR/drivers/kernelsu && git rev-list --count HEAD)
		let KSU_VER=KSU_VERSION+KSU_GIT_VERSION
}

function check_ksutag {
                #KSU_TAG=$(cd $KDIR/drivers/kernelsu && git describe --tags --abbrev=0)
		KSU_TAG=v3.2.5
}

function make_zip {
		cd $REPACK_DIR
		xksu=$(cd $KDIR && grep -q '^CONFIG_KSU_XXKSU=y' $CFGOUT && echo "y" || echo "n")
		suki=$(cd $KDIR && grep -q '^CONFIG_KSU_SUKI=y' $CFGOUT && echo "y" || echo "n")
        	ksun=$(cd $KDIR && grep -q '^CONFIG_KSU_NEXT=y' $CFGOUT && echo "y" || echo "n")

		if [ $xksu == "y" ]; then
		  ZIPED=$ZIP_MOVE/`echo $ZIP_NAME-XXKSU-SUSFS`.zip
		  ZIPSTRING=`echo $ZIP_NAME-XXKSU-SUSFS`
		  zip -r9 `echo $ZIP_NAME-XXKSU-SUSFS`.zip *
		  check_ksuver && check_ksutag
		  SUSFS_VER=$(grep -oP '(?<=#define SUSFS_VERSION ")[^"]*' $KDIR/include/linux/susfs.h 2>/dev/null)
		elif [ $suki == "y" ]; then
		  ZIPED=$ZIP_MOVE/`echo $ZIP_NAME-SUKISU-SUSFS`.zip
          	  ZIPSTRING=`echo $ZIP_NAME-SUKISU-SUSFS`
          	  zip -r9 `echo $ZIP_NAME-SUKISU-SUSFS`.zip *
          	  check_ksuver && check_ksutag
          	  SUSFS_VER=$(grep -oP '(?<=#define SUSFS_VERSION ")[^"]*' $KDIR/include/linux/susfs.h 2>/dev/null)
		elif [ $ksun == "y" ]; then
		  ZIPED=$ZIP_MOVE/`echo $ZIP_NAME-KSUNEXT-SUSFS`.zip
            	  ZIPSTRING=`echo $ZIP_NAME-KSUNEXT-SUSFS`
          	  zip -r9 `echo $ZIP_NAME-KSUNEXT-SUSFS`.zip *
          	  check_ksuver && check_ksutag
          	  SUSFS_VER=$(grep -oP '(?<=#define SUSFS_VERSION ")[^"]*' $KDIR/include/linux/susfs.h 2>/dev/null)
		else
		  ZIPED=$ZIP_MOVE/`echo $ZIP_NAME`.zip
		  ZIPSTRING=`echo $ZIP_NAME`
		  zip -r9 `echo $ZIP_NAME`.zip *
		  KSU_VER=Disabled
		  KSU_TAG=Disabled
          	  SUSFS_VER=Disabled
		fi
		mv  `echo $ZIP_NAME`*.zip $ZIP_MOVE
		cd $KDIR
}

function upload()
{
		#curl bashupload.com -T $ZIP_NAME*.zip
		source $KDIR/.dump
		#ziped=$ZIP_MOVE/`echo $ZIP_NAME`.zip
	        sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no "$ZIPED" "$USER@$HOST:$REMOTE_DIR"
}

function upload_boolx_action()
{
                #ziped=$ZIP_MOVE/`echo $ZIP_NAME`.zip
                cd $KDIR
                #wget
                chmod +x $upl
                sed -i "4i\FILE_PATH=$ZIPED" $upl
                BUILDDATE=`date +"%Y-%m-%d"`
                sed -i '5i\CAPTION="* Build Date: '$BUILDDATE'' $upl
                sed -i '6i\* Kernel Version: '$KER_VER'' $upl
                sed -i '7i\* XXKSU: '$KSU_VER'' $upl
                sed -i '8i\* XXKSU Tag: '$KSU_TAG'' $upl
                sed -i '9i\* SUSFS: '$SUSFS_VER'' $upl
                sed -i '10i\* Type: AOSP, Non-Dynamic,' $upl
                sed -i '11i\* Changes: https://github.com/onettboots/boolx-ginkgo/tree/16-ups' $upl
            	sed -i '12i\* Clang: Boolx Clang 22.0.0' $upl
            	sed -i '13i\' $upl
            	sed -i '14i\*NOTES: initial build report bugs directly"' $upl
            	bash $upl
}

DATE_START=$(date +"%s")

echo -e "${green}"
echo "----------------------"
echo "Checking Toolchains:"
echo "----------------------"
echo -e "${restore}"
sleep 1
if [ -d $TOOLCHAINS ]; then
   echo -e "${red}"
   echo "Bool-x clang is ready..!!"
   echo -e "${restore}"
else
   echo -e "${green}"
   echo "Toolchains Architecture Host:"
   echo "1. ARCH64"
   echo "2. X86"
   while read -p "Choose your architecture (1 / 2)? " cchoice
do
case "$cchoice" in
        1 )
                echo
                echo "Downloading Boolx-clang for Aarch64 host."
                git clone https://gitlab.com/onettboots/boolx-clang.git -b Clang-15.0 $TOOLCHAINS
                break
                ;;
        2 )
                echo
                echo "Downloading Boolx-clang 22.0.0 for X86 host."
                wget https://github.com/onettboots/boolx-clang-build/releases/download/Boolx-22/boolx-clang22.tar.zst -P $SAVEHERE
                cd $SAVEHERE
                echo "Extracting Boolx Clang 22.0.0 to $HOME/toolchains/:"
                tar --use-compress-program=unzstd -xf boolx-clang22.tar.zst
                break
                ;;
        * )
                echo
                echo "Invalid try again!"
                echo
                ;;
esac
done
   echo -e "${restore}"
fi
sleep 1
clear
echo -e "${green}"
#echo "-----------------------"
echo "$HELP"
#echo "-----------------------"
echo -e "${restore}"

echo -e "${green}"
echo "----------------------------------"
echo "Checking for Anykernel flashable:"
echo "----------------------------------"
echo -e "${restore}"
sleep 1
if [ -d $REPACK_DIR ] && [ -d $ZIP_MOVE ]; then
   echo -e "${red}"
   echo "Anykernel is ready skipping..!!"
   echo -e "${restore}"
else
   echo -e "${red}"
   echo "Adding Anykernel flashable.!!"
   create_out
   echo -e "${restore}"
fi
sleep 1
clear
echo -e "${green}"
echo "$HELP"
echo -e "${restore}"

function checkconfig() {
    local config_file="$1"
    make_config
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        echo -e "${green}${stuff}${restore}"
        ARCH=arm64 scripts/kconfig/merge_config.sh -m -O out/ "out/.config" "$config_file" > /dev/null 2>&1
        make -s O=out ARCH=arm64 olddefconfig > /dev/null 2>&1
    fi
}

function make_config() {
    make -s O=out ARCH=arm64 ${BASE_DEFCONFIG} > /dev/null 2>&1
}

function clean_all() {
    rm -rf out/
}

IS_CLEAN=false
for arg in "$@"; do
    case "$arg" in
        clean|clean_all|--clean)
            IS_CLEAN=true
            break
            ;;
    esac
done

cd ${KDIR}
if [ $# -eq 0 ]; then
    #checkconfig="$BASE_DEFCONFIG"
    checkconfig
    exit 0
fi
echo -e "${green}"

echo "-----------------------"
echo " TASK :"
echo "-----------------------"
echo -e "${restore}"

sleep 1

# check args
for arg in "$@"; do
    case "$arg" in
        clean|-c|--clean)
            sleep 0.5
            echo -e "${red}- Clean build${restore}"
            echo -e "${green}- Cleaning build directory...${restore}"
            clean_all
            ;;
        xksu|--xksu|-x)
            sleep 0.5
            echo -e "${red}- XXKSU build${restore}"
            stuff="- Adding XXKSU Stuffs.."
            if [ "$IS_CLEAN" = false ]; then
                sleep 0.5
                echo -e "${red}- Dirty build${restore}"
                sleep 1
            fi
            
            checkconfig "arch/arm64/configs/xxksu.config"
            ;;
        sukisu|-s|--sukisu)
            sleep 0.5
            echo -e "${red}- SUKISU build${restore}"
            stuff="- Adding SUKISU Stuffs.."
            if [ "$IS_CLEAN" = false ]; then
                sleep 0.5
                echo -e "${red}- Dirty build${restore}"
                sleep 1
            fi
            
            checkconfig "arch/arm64/configs/sukisu.config"
            ;;
        ksun|-k|--ksun)
            sleep 0.5
            echo -e "${red}- KSUNEXT build${restore}"
            stuff="- Adding KSUNEXT Stuffs.."
            if [ "$IS_CLEAN" = false ]; then
                sleep 0.5
                echo -e "${red}- Dirty build${restore}"
                sleep 1
            fi
            
            checkconfig "arch/arm64/configs/ksu.config"
            ;;
        normal|-n|--normal)
            sleep 0.5
            echo -e "${red}- Normal build (Stock Defconfig)${restore}"
            stuff="- Using base defconfig only.."
            if [ "$IS_CLEAN" = false ]; then
                sleep 0.5
                echo -e "${red}- Dirty build${restore}"
                sleep 1
            fi

            checkconfig
            ;;
        help|-h|--help)
            HELP
            ;;
    esac
done

echo -e "${yellow}"
build ${TARGET_IMAGE} > logs.txt 2>&1 &
BUILD_PID=$!
progress
wait $BUILD_PID
dtbo_build > /dev/null 2>&1
echo -e "${restore}"

function build_time {
   DATE_END=$(date +"%s")
   DIFF=$(($DATE_END - $DATE_START))
   echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

if [ -f $KERNEL ]; then
   echo -e "${green}"
   echo "------------------------------------------"
   echo "Succesed Build, make flashable zip"
   echo "------------------------------------------"
   echo -e "${restore}"
   make_boot
   make_zip
   cd $ZIP_MOVE
   echo -e "${blink_red}"
   echo $ZIP_MOVE
   echo "------------------------------------------"
   echo $ZIP_NAME*.zip
   echo "------------------------------------------"
   echo -e "${restore}"
   build_time
   if [[ -f "$KDIR/.dump" ]]; then
    upload
   elif [[ -f "$upl" ]]; then
    upload_boolx_action
   else
    echo ""
   fi
   echo
else
   echo -e "${red}"
   echo "-------------------------------------"
   echo "Building failed, Fix it and rebuild...!!!"
   echo "-------------------------------------"
   echo -e "${restore}"
   build_time
fi
echo

# End
#rm -rf $upl
#cd $KDIR
#git restore $CFG
