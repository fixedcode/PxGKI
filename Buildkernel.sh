#!/bin/bash

# Settings

# Kernel Android Release
export Android_Release="15"

# Kernel Version
export Kernel_Version="6.6"

# Kernel Security Patch or lts (latest)
# Recommend same as stock kernel
export Security_Patch="2025-09"

# Kernel Suffix
# Set (Kernel_Suffix="") meaning delete dirty suffix
# or using custom suffix to replace it
# Recommend same as stock kernel
export Kernel_Suffix="g4b48560cd07d-ab14239520-4k"

# Kernel Build Timestamp
# Recommend same as stock kernel
export Kernel_Time="Thu Oct  9 05:51:31 UTC 2025"

echo
echo -e "\e[32mKernel information preview\e[0m"
echo Android：$Android_Release
echo Version：$Kernel_Version
echo Security Patch：$Security_Patch
if [[ "$Kernel_Suffix" == "" ]]; then
  echo Delete the dirty suffix
else
  echo Custom suffix：$Kernel_Suffix
fi
echo Build Timestamp：$Kernel_Time
echo

echo -e "\e[33mCheck the settings before starting\e[0m"
echo -e "\e[33mPress Ctrl+C to exit during execution\e[0m"
echo

read -n 1 -s -p "Press any key to continue"
echo

# Select KPM feature
while true; do
  read -p "KPM Feature (y=Enable, n=Disable): " kpm
  if [[ "$kpm" == "y" || "$kpm" == "n" ]]; then
    export KERNEL_KPM="$kpm"
    break
  else
    echo -e "\e[31m[Error]\e[33m Please select：y or n\e[0m"
  fi
done

# Install tools (APT is used by default)
echo -e "\e[32mInstall tools\e[0m"
sudo apt update 
sudo apt upgrade -y
sudo apt-get install -y curl git python3 zip

# Set up repo
echo -e "\e[32mSet up repo\e[0m"
curl https://storage.googleapis.com/git-repo-downloads/repo > $HOME/PxGKI/repo
chmod a+x $HOME/PxGKI/repo
sudo mv $HOME/PxGKI/repo /usr/local/bin/repo

# Sync GKI Source Code
echo -e "\e[32mSync GKI source code\e[0m"
mkdir Buildkernel
cd Buildkernel
git config --global user.email "usererror404@gmail.com"
git config --global user.name "usererror404"
repo init -u https://android.googlesource.com/kernel/manifest -b common-android$Android_Release-$Kernel_Version-$Security_Patch --depth=1
repo sync

# Fix 6.6 build
if [[ "$Kernel_Version" == "6.6" ]]; then
cd $HOME/PxGKI/Buildkernel/common
fake_patched=0
  if ! grep -qxF $'\tunsigned int nr_subpages = __PAGE_SIZE / PAGE_SIZE;' ./fs/proc/task_mmu.c; then
    echo "Can't find nr_subpages, try to repair"
    sed -i -e '/int ret = 0, copied = 0;/a \\tunsigned int nr_subpages \= __PAGE_SIZE \/ PAGE_SIZE;' -e '/int ret = 0, copied = 0;/a \\tpagemap_entry_t \*res = NULL;' ./fs/proc/task_mmu.c
    fake_patched=1
  fi
fi

if [ "$fake_patched" = 1 ]; then
  if [ "$Kernel_Version" = "6.6" ]; then
    if grep -qxF $'\tunsigned int nr_subpages = __PAGE_SIZE / PAGE_SIZE;' ./fs/proc/task_mmu.c; then
      sed -i -e '/unsigned int nr_subpages \= __PAGE_SIZE \/ PAGE_SIZE;/d' -e '/pagemap_entry_t \*res = NULL;/d' ./fs/proc/task_mmu.c
    fi
  fi
fi

# Set up SukiSU-Ultra
echo -e "\e[32mSet up SukiSU-Ultra\e[0m"
cd $HOME/PxGKI/Buildkernel
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin

# Set up susfs
echo -e "\e[32mSet up susfs\e[0m"
cd $HOME/PxGKI/Buildkernel
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android$Android_Release-$Kernel_Version
cp susfs4ksu/kernel_patches/50_add_susfs_in_gki-android$Android_Release-$Kernel_Version.patch ./common/
cp susfs4ksu/kernel_patches/fs/* ./common/fs/
cp susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
cd common
patch -p1 -F 3 < 50_add_susfs_in_gki-android$Android_Release-$Kernel_Version.patch

echo -e "\e[32mKernel configuration\e[0m"

# Add configuration to kernel
cd $HOME/PxGKI/Buildkernel
# susfs
echo "CONFIG_KSU=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> ./common/arch/arm64/configs/gki_defconfig
# tmpfs
echo "CONFIG_TMPFS_XATTR=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_TMPFS_POSIX_ACL=y" >> ./common/arch/arm64/configs/gki_defconfig
sed -i 's/check_defconfig//' ./common/build.config.gki
echo -e "\e[33m[Done]\e[0m" Add configuration to kernel

# Add KPM configuration to kernel
if [ "$KERNEL_KPM" = "y" ]; then
  cd $HOME/PxGKI/Buildkernel  
  echo "CONFIG_KPM=y" >> common/arch/arm64/configs/gki_defconfig
  echo -e "\e[33m[Done]\e[0m" Add KPM configuration to kernel
  echo -e "\e[33m[Done]\e[0m" Enable KPM feature
else
  echo -e "\e[33m[Done]\e[0m" Disable KPM feature
fi

# Set up kernel suffix
cd $HOME/PxGKI/Buildkernel
if [[ "$Kernel_Version" == "6.1" ]] &&  [[ "$Kernel_Suffix" == "" ]]; then
  sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl
  echo -e "\e[33m[Done]\e[0m" Delete the dirty suffix
fi
if [[ "$Kernel_Version" == "6.6" ]] &&  [[ "$Kernel_Suffix" == "" ]]; then
  sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl
  sed -i '/^CONFIG_LOCALVERSION=/ s/="\([^"]*\)"/=""/' ./common/arch/arm64/configs/gki_defconfig
  echo -e "\e[33m[Done]\e[0m" Delete the dirty suffix
fi 
if [[ "$Kernel_Version" == "6.1" ]] &&  [[ "$Kernel_Suffix" != "" ]]; then
  sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl
  sed -i '$s|echo "\$res"|echo "$res-'"$Kernel_Suffix"'"|' ./common/scripts/setlocalversion
  echo -e "\e[33m[Done]\e[0m" Set up custom suffix
fi
if [[ "$Kernel_Version" == "6.6" ]] &&  [[ "$Kernel_Suffix" != "" ]]; then
  sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl
  sed -i "\$s|echo \"\\\$res\"|echo \"-$Kernel_Suffix\"|" ./common/scripts/setlocalversion
  sudo sed -i "s/-4k/-$Kernel_Suffix/g" ./common/arch/arm64/configs/gki_defconfig
  echo -e "\e[33m[Done]\e[0m" Set up custom suffix
fi

# Set up kernel build timestamp
cd $HOME/PxGKI/Buildkernel
perl -pi -e "s{UTS_VERSION=\"\\\$\(echo \\\$UTS_VERSION \\\$CONFIG_FLAGS \\\$TIMESTAMP \\| cut -b -\\\$UTS_LEN\)\"}{UTS_VERSION=\"#1 SMP PREEMPT $Kernel_Time\"}" ./common/scripts/mkcompile_h
sed -i -e "s|\$(preempt-flag-y) \"\$(build-timestamp)\"|\$(preempt-flag-y) \"$Kernel_Time\"|" ./common/init/Makefile
echo -e "\e[33m[Done]\e[0m" Set up kernel build timestamp

# Build kernel
cd $HOME/PxGKI/Buildkernel
echo -e "\e[32mBuilding kernel\e[0m"
sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' ./common/BUILD.bazel
rm -rf ./common/android/abi_gki_protected_exports_*
sed -i 's/BUILD_SYSTEM_DLKM=1/BUILD_SYSTEM_DLKM=0/' common/build.config.gki.aarch64
sed -i '/MODULES_ORDER=android\/gki_aarch64_modules/d' common/build.config.gki.aarch64
sed -i '/KMI_SYMBOL_LIST_STRICT_MODE/d' common/build.config.gki.aarch64
tools/bazel run --config=fast --lto=thin //common:kernel_aarch64_dist -- --destdir=dist

# KPM patch
if [ "$KERNEL_KPM" = "y" ]; then
  echo -e "\e[32mKPM patch\e[0m"
  cd dist
  curl -LO "https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/refs/heads/main/kpm/patch_linux"
  chmod 777 patch_linux
  ./patch_linux
  rm Image
  mv oImage Image
  cp Image kernel
  echo -e "\e[33m[Done]\e[0m" KPM feature is enabled
else
  cd dist
  cp Image kernel
fi

# Set up AnyKernel3
echo -e "\e[32mSet up AnyKernel3\e[0m"
cd $HOME/PxGKI/Buildkernel
git clone https://github.com/SukiSU-Ultra/SukiSU_patch.git

# Create AnyKernel3
echo -e "\e[32mCreate AnyKernel3\e[0m"
cd $HOME/PxGKI/Buildkernel/SukiSU_patch/AnyKernel3
cp $HOME/PxGKI/Buildkernel/dist/Image $HOME/PxGKI/Buildkernel/SukiSU_patch/AnyKernel3
zip -r "android$Android_Release-$Kernel_Version-AnyKernel3.zip" ./*

# Output Kernel and AnyKernel3
cd $HOME/PxGKI/Buildkernel/
mkdir patched
cd patched
cp $HOME/PxGKI/Buildkernel/dist/kernel $HOME/PxGKI/Buildkernel/patched/
cp $HOME/PxGKI/Buildkernel/SukiSU_patch/AnyKernel3/android$Android_Release-$Kernel_Version-AnyKernel3.zip $HOME/PxGKI/Buildkernel/patched/
echo -e "\e[33m[Done]\e[0m" Complete
echo -e "\e[32mINFO:\e[0m" Output to PxGKI/Buildkernel/patched
