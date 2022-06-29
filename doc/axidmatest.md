# Background information

This page is trying to digest and understand the axidmatest.c kernel module source code from following link:

https://github.com/Xilinx/linux-xlnx/blob/xilinx-v2021.2/drivers/dma/xilinx/axidmatest.c

There are two paramters for this kernel module: test_buf_size and iterations

```
static unsigned int test_buf_size = 16384;
module_param(test_buf_size, uint, 0444);
MODULE_PARM_DESC(test_buf_size, "Size of the memcpy test buffer");

static unsigned int iterations = 5;
module_param(iterations, uint, 0444);
MODULE_PARM_DESC(iterations,
		 "Iterations before stopping test (default: infinite)");
```


The follwing is the main entry of the module kernel

```
static int __init axidma_init(void)
{
	return platform_driver_register(&xilinx_axidmatest_driver);
}
```

platform_driver_register() is coming from include <linux/platform_device.h>

https://www.kernel.org/doc/Documentation/driver-model/platform.txt

Obviously, this kernel module is leveraging the platform devices and drivers to manage this device.Platform drivers follow the standard driver model convention, where discovery/enumeration is handled outside the drivers, and drivers provide probe() and remove() methods.

So, make sure we have "xlnx,axi-dma-test-1.00.a" in device tree to enable this driver.  


```
static const struct of_device_id xilinx_axidmatest_of_ids[] = {
	{ .compatible = "xlnx,axi-dma-test-1.00.a",},
	{}
};


static struct platform_driver xilinx_axidmatest_driver = {
	.driver = {
		.name = "xilinx_axidmatest",
		.of_match_table = xilinx_axidmatest_of_ids,
	},
	.probe = xilinx_axidmatest_probe,
	.remove = xilinx_axidmatest_remove,
};
```

So, let's check out the probe method

```
chan = dma_request_chan(&pdev->dev, "axidma0");
```

dma_request_chan() is coming from include <linux/dmaengine.h>. This file provide a standard dma engine layer for all dma controller. This is the first step to access the DMA functionality. 

The chan is the return value of dma_request_chan() and it's the handler of this dma engine. In this code, it requests to separated channle for read and write



```
err = dmatest_add_slave_channels(chan, rx_chan);

```

In above function, it allocate the memory for rx_dtc and assign rx_chan to that strcuture

```
rx_dtc = kmalloc(sizeof(struct dmatest_chan), GFP_KERNEL);
.....
rx_dtc->chan = rx_chan;

```

then goto 
```
dmatest_add_slave_threads(tx_dtc, rx_dtc);
```

In above function, it setup everything for create kernel threads to start Rx/Tx DMA at the same time

```
	thread->task = kthread_run(dmatest_slave_func, thread, "%s-%s",
				   dma_chan_name(tx_chan),
				   dma_chan_name(rx_chan));
```

let's check the dmatest_slave_func() 

The following codes are allocating memeory space and setup the BD for SG DMA. The BD number is coming from the XILINX_DMATEST_BD_CNT definition. The default value is 11 and you could change it any value you like. 

```
	thread->srcs = kcalloc(src_cnt + 1, sizeof(u8 *), GFP_KERNEL);
	if (!thread->srcs)
		goto err_srcs;
	for (i = 0; i < src_cnt; i++) {
		thread->srcs[i] = kmalloc(test_buf_size, GFP_KERNEL);
		if (!thread->srcs[i])
			goto err_srcbuf;
	}
	thread->srcs[i] = NULL;

	thread->dsts = kcalloc(dst_cnt + 1, sizeof(u8 *), GFP_KERNEL);
	if (!thread->dsts)
		goto err_dsts;
	for (i = 0; i < dst_cnt; i++) {
		thread->dsts[i] = kmalloc(test_buf_size, GFP_KERNEL);
		if (!thread->dsts[i])
			goto err_dstbuf;
	}
	thread->dsts[i] = NULL;
```

After all the data has been setup in those buffers, the following dma_map_single() is called to flush the data in cache to memory. 

```
dma_srcs[i] = dma_map_single(tx_dev->dev, buf, len, DMA_MEM_TO_DEV);
```

device_prep_slave_sg() 
preparing different type of descriptor and buffer for later DMA transfering
```							 
rxd = rx_dev->device_prep_slave_sg(rx_chan, rx_sg, bd_cnt,
		DMA_DEV_TO_MEM, flags, NULL);

txd = tx_dev->device_prep_slave_sg(tx_chan, tx_sg, bd_cnt,
		DMA_MEM_TO_DEV, flags, NULL);
```		


Setup the callback function and submit the DMA transaction reqeusts

```
rxd->callback = dmatest_slave_rx_callback;
rxd->callback_param = &rx_cmp;
rx_cookie = rxd->tx_submit(rxd);
```

dma_async_issue_pending() will start the DMA request in the queue. This function is coming from <linux/dmaengine.h>
		
```	
dma_async_issue_pending(rx_chan);
dma_async_issue_pending(tx_chan);	
```

let's check the dma_async_issue_pending()

```
static inline void dma_async_issue_pending(struct dma_chan *chan)
{
	chan->device->device_issue_pending(chan);
}
```

Let's check where is the function of implementing the DMA 

variable name:

rx_chan->device->device_issue_pending()

structure name:

dma_chan->dma_device->device_issue_pending()


```
struct dma_chan {
	struct dma_device *device;
	dma_cookie_t cookie;
	dma_cookie_t completed_cookie;

	/* sysfs */
	int chan_id;
	struct dma_chan_dev *dev;

	struct list_head device_node;
	struct dma_chan_percpu __percpu *local;
	int client_count;
	int table_count;

	/* DMA router */
	struct dma_router *router;
	void *route_data;

	void *private;
};


struct dma_device {

	unsigned int chancnt;
	unsigned int privatecnt;
	struct list_head channels;
	struct list_head global_node;
	struct dma_filter filter;
	dma_cap_mask_t  cap_mask;
	unsigned short max_xor;
	unsigned short max_pq;
	enum dmaengine_alignment copy_align;
	enum dmaengine_alignment xor_align;
	enum dmaengine_alignment pq_align;
	enum dmaengine_alignment fill_align;
	#define DMA_HAS_PQ_CONTINUE (1 << 15)

	int dev_id;
	struct device *dev;

	u32 src_addr_widths;
	u32 dst_addr_widths;
	u32 directions;
	u32 max_burst;
	bool descriptor_reuse;
	enum dma_residue_granularity residue_granularity;

	int (*device_alloc_chan_resources)(struct dma_chan *chan);
	void (*device_free_chan_resources)(struct dma_chan *chan);

	struct dma_async_tx_descriptor *(*device_prep_dma_memcpy)(
		struct dma_chan *chan, dma_addr_t dst, dma_addr_t src,
		size_t len, unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_xor)(
		struct dma_chan *chan, dma_addr_t dst, dma_addr_t *src,
		unsigned int src_cnt, size_t len, unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_xor_val)(
		struct dma_chan *chan, dma_addr_t *src,	unsigned int src_cnt,
		size_t len, enum sum_check_flags *result, unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_pq)(
		struct dma_chan *chan, dma_addr_t *dst, dma_addr_t *src,
		unsigned int src_cnt, const unsigned char *scf,
		size_t len, unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_pq_val)(
		struct dma_chan *chan, dma_addr_t *pq, dma_addr_t *src,
		unsigned int src_cnt, const unsigned char *scf, size_t len,
		enum sum_check_flags *pqres, unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_memset)(
		struct dma_chan *chan, dma_addr_t dest, int value, size_t len,
		unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_memset_sg)(
		struct dma_chan *chan, struct scatterlist *sg,
		unsigned int nents, int value, unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_interrupt)(
		struct dma_chan *chan, unsigned long flags);

	struct dma_async_tx_descriptor *(*device_prep_slave_sg)(
		struct dma_chan *chan, struct scatterlist *sgl,
		unsigned int sg_len, enum dma_transfer_direction direction,
		unsigned long flags, void *context);
	struct dma_async_tx_descriptor *(*device_prep_dma_cyclic)(
		struct dma_chan *chan, dma_addr_t buf_addr, size_t buf_len,
		size_t period_len, enum dma_transfer_direction direction,
		unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_interleaved_dma)(
		struct dma_chan *chan, struct dma_interleaved_template *xt,
		unsigned long flags);
	struct dma_async_tx_descriptor *(*device_prep_dma_imm_data)(
		struct dma_chan *chan, dma_addr_t dst, u64 data,
		unsigned long flags);

	int (*device_config)(struct dma_chan *chan,
			     struct dma_slave_config *config);
	int (*device_pause)(struct dma_chan *chan);
	int (*device_resume)(struct dma_chan *chan);
	int (*device_terminate_all)(struct dma_chan *chan);
	void (*device_synchronize)(struct dma_chan *chan);

	enum dma_status (*device_tx_status)(struct dma_chan *chan,
					    dma_cookie_t cookie,
					    struct dma_tx_state *txstate);
	void (*device_issue_pending)(struct dma_chan *chan);
};


```

In xilinx_dma.c, there is the implemenation of device_issue_pending() which is defined in xilinx_dma_issue_pending()


```
xdev->common.device_issue_pending = xilinx_dma_issue_pending;
```

xilinx_dma_issue_pending() will call chan->start_transfer(chan);

```
static void xilinx_dma_issue_pending(struct dma_chan *dchan)
{
	struct xilinx_dma_chan *chan = to_xilinx_chan(dchan);
	unsigned long flags;

	spin_lock_irqsave(&chan->lock, flags);
	chan->start_transfer(chan);
	spin_unlock_irqrestore(&chan->lock, flags);
}

```

in xilinx_dma.c of xilinx_dma_chan_probe() linked the chan->start_transfer to different type of the DMA

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

Then go to xilinx_dma_start_transfer() to get all the hardware related register access to enable the DMA 
