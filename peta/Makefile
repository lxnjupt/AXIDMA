DL_DR			= $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/downloads
SSTATE_DIR		= $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/sstate-cache



.PHONY: all clean sync_platform_boot sync_saved_boot_common

all:
	cp -f ../hw/*.xsa ./
	
	@echo "using BSP file: $(BSP_FILE)"
	petalinux-create -t project -s $(BSP_FILE) -n AXI_DMA
	
	

# enable auto-login
	@sed -i -E 's/.*CONFIG_auto-login.+/CONFIG_auto-login=y/' AXI_DMA/project-spec/configs/rootfs_config

# added for 2021.1 to workaround git-lfs issue
	@sed -i -E 's/.*CONFIG_aie-matrix-multiplication.+/CONFIG_aie-matrix-multiplication=n/' AXI_DMA/project-spec/configs/rootfs_config
	@sed -i -E 's/.*CONFIG_aie-notebooks.+/CONFIG_aie-notebooks=n/' AXI_DMA/project-spec/configs/rootfs_config
# saw nfs error during boot up with 22.1 
	@sed -i -E 's/.*CONFIG_nfs-utils.+/CONFIG_nfs-utils=n/' AXI_DMA/project-spec/configs/rootfs_config
	





# CONFIG_YOCTO_ENABLE_DEBUG_TWEAKS=y
	@sed -i -E 's/.*CONFIG_YOCTO_ENABLE_DEBUG_TWEAKS.+/CONFIG_YOCTO_ENABLE_DEBUG_TWEAKS=y/' AXI_DMA/project-spec/configs/config
	
#enable ext4 rootfs
	@sed -i -E 's/.*CONFIG_SUBSYSTEM_ROOTFS_EXT4.+/CONFIG_SUBSYSTEM_ROOTFS_EXT4=y/' AXI_DMA/project-spec/configs/config

#disable RAMFS

	@sed -i -E 's/.*CONFIG_SUBSYSTEM_ROOTFS_INITRD.+/# CONFIG_SUBSYSTEM_ROOTFS_INITRD is not set/' AXI_DMA/project-spec/configs/config
	

ifneq ($(PETALINUX_SSTATE),)
	@echo "using PETALINUX_SSTATE path: $(PETALINUX_SSTATE)"
	@sed -i -E 's/CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL/#CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL/g' AXI_DMA/project-spec/configs/config
	@sed -i -E '/CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL/a CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL="$(PETALINUX_SSTATE)"' AXI_DMA/project-spec/configs/config
endif

ifneq ($(PETALINUX_DOWNLOADS),)
	@echo "using PETALINUX_DOWNLOADS path: $(PETALINUX_DOWNLOADS)"
	@sed -i -E 's/CONFIG_PRE_MIRROR_URL=/#CONFIG_PRE_MIRROR_URL=/g' AXI_DMA/project-spec/configs/config
	@sed -i -E '/CONFIG_PRE_MIRROR_URL=/a CONFIG_PRE_MIRROR_URL="file://$(PETALINUX_DOWNLOADS)"' AXI_DMA/project-spec/configs/config
endif

#	echo $(DL_DR)
#	echo $(SSTATE_DIR)
	echo 'DL_DIR = "$(DL_DR)"' >> AXI_DMA/project-spec/meta-user/conf/petalinuxbsp.conf
	echo 'SSTATE_DIR = "$(SSTATE_DIR)"' >> AXI_DMA/project-spec/meta-user/conf/petalinuxbsp.conf
	
#	added for 2021.1 | Removed for 2021.2 |add back for 22.1
	echo 'CONFIG_YOCTO_BUILDTOOLS_EXTENDED=y' >> AXI_DMA/project-spec/configs/config	

#   add axidmatest to device tree
	cp system-user.dtsi ./AXI_DMA/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
	
#	apply config for kernel to enable axidmatest
	echo 'CONFIG_XILINX_DMATEST=y' >> ./AXI_DMA/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg
	
#	cp user_2022-06-22-15-08-00.cfg ./AXI_DMA/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg

	petalinux-config -p AXI_DMA --get-hw-description=. --silentconfig
	petalinux-config -p AXI_DMA -c rootfs --silentconfig 
	petalinux-config -p AXI_DMA -c kernel --silentconfig 
	petalinux-config -p AXI_DMA --silentconfig
	petalinux-build -p AXI_DMA

	cd AXI_DMA && petalinux-package --boot --u-boot
	

clean:
	rm -rf AXI_DMA
	rm -rf *.xsa

ultra_clean:
	rm -rf AXI_DMA
	rm -rf *.xsa
	rm -rf downloads sstate-cache

