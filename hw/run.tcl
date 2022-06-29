create_project axi_dma ./axi_dma -part xcvc1902-vsva2197-2MP-e-S
set_property board_part xilinx.com:vck190:part0:3.0 [current_project]



source ./bd.tcl

save_bd_design
validate_bd_design


make_wrapper -files [get_files ./axi_dma/axi_dma.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./axi_dma/axi_dma.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_device_image -jobs 8
wait_on_run impl_1



write_hw_platform -fixed -include_bit -force -file ./axi_dma_post_implt.xsa

