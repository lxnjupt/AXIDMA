# Xilinx AXI DMA driver Digest Notes

After understanding the AXI DMA related drivers from the perspect of axidmatest.c code. There are lots of methods and functions are called from xilinx_dma.c. It's worth to dig deeper on this driver to understand more on DMA. 

https://github.com/Xilinx/linux-xlnx/blob/xilinx-v2021.2/drivers/dma/xilinx/xilinx_dma.c


Same here, we get the entry of this kernel module is xilinx_dma_probe. The ids is the list of compabible device from the DTS to passing configuration to driver. 

```
static struct platform_driver xilinx_vdma_driver = {
	.driver = {
		.name = "xilinx-vdma",
		.of_match_table = xilinx_dma_of_ids,
	},
	.probe = xilinx_dma_probe,
	.remove = xilinx_dma_remove,
};

......

static const struct of_device_id xilinx_dma_of_ids[] = {
	{ .compatible = "xlnx,axi-dma-1.00.a", .data = &axidma_config },
	{ .compatible = "xlnx,axi-cdma-1.00.a", .data = &axicdma_config },
	{ .compatible = "xlnx,axi-vdma-1.00.a", .data = &axivdma_config },
	{ .compatible = "xlnx,axi-mcdma-1.00.a", .data = &aximcdma_config },
	{}
};
```


xilinx_dma_probe() 

It will use the xilinx_dma_of_ids[] to match the device tree,  map the I/O memory, start analyzing the configuration and configure the DMA controller accordingly different type of DMA engine


```
match = of_match_node(xilinx_dma_of_ids, np);

....

xdev->regs = devm_platform_ioremap_resource(pdev, 0);

```

After the DMA engine configuration, it will configure each DMA channels based how many channels are available in this DMA engine. It will call the xilinx_dma_child_probe() and then xilinx_dma_chan_probe() to setup the methods 

```
/* Initialize the channels */
for_each_child_of_node(node, child) {
	err = xilinx_dma_child_probe(xdev, child);
	if (err < 0)
		goto disable_clks;
}

static int xilinx_dma_child_probe(struct xilinx_dma_device *xdev,
				    struct device_node *node)
{
	int ret, i;
	u32 nr_channels = 1;

	ret = of_property_read_u32(node, "dma-channels", &nr_channels);
	if (xdev->dma_config->dmatype == XDMA_TYPE_AXIMCDMA && ret < 0)
		dev_warn(xdev->dev, "missing dma-channels property\n");

	for (i = 0; i < nr_channels; i++) {
		ret = xilinx_dma_chan_probe(xdev, node);
		if (ret)
			return ret;
	}

	return 0;
}
```

Here, the code will assign different methods to structure of xilinx_dma_chan. As for AXI DMA, there are xilinx_dma_start_transfer() and xilinx_dma_start_transfer() assigned to chan->start_transfer() and chan->stop_transfer()

```
if (xdev->dma_config->dmatype == XDMA_TYPE_AXIDMA) {
		chan->start_transfer = xilinx_dma_start_transfer;
		chan->stop_transfer = xilinx_dma_stop_transfer;
	} else if (xdev->dma_config->dmatype == XDMA_TYPE_AXIMCDMA) {
		chan->start_transfer = xilinx_mcdma_start_transfer;
		chan->stop_transfer = xilinx_dma_stop_transfer;
	} else if (xdev->dma_config->dmatype == XDMA_TYPE_CDMA) {
		chan->start_transfer = xilinx_cdma_start_transfer;
		chan->stop_transfer = xilinx_cdma_stop_transfer;
	} else {
		chan->start_transfer = xilinx_vdma_start_transfer;
		chan->stop_transfer = xilinx_dma_stop_transfer;
	}

```	


In the method of xilinx_dma_start_transfer() will access the hardware register to setup the DMA related control and query the status register as well. dma_ctrl_write() and dma_ctrl_read() will generate DMA controller register access. The XILINX_DMA_REG_DMACR and XILINX_DMA_REG_DMACR will show the registers address offset. 


```
reg = dma_ctrl_read(chan, XILINX_DMA_REG_DMACR);
	if (chan->desc_pendingcount <= XILINX_DMA_COALESCE_MAX) {
		reg &= ~XILINX_DMA_CR_COALESCE_MAX;
		reg |= chan->desc_pendingcount <<
				  XILINX_DMA_CR_COALESCE_SHIFT;
		dma_ctrl_write(chan, XILINX_DMA_REG_DMACR, reg);

```