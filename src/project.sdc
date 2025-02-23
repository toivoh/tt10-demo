read_sdc $::env(SCRIPTS_DIR)/base.sdc

set_multicycle_path -setup -through {*player.mc_buffer_osc.bits[*].mc_buf *player.mc_buffer_channel.bits[*].mc_buf *field_top.mc_buffer_afl_pc.bits[*].mc_buf *field_top.mc_buffer_afl_section.bits[*].mc_buf} 2
set_multicycle_path -hold  -through {*player.mc_buffer_osc.bits[*].mc_buf *player.mc_buffer_channel.bits[*].mc_buf *field_top.mc_buffer_afl_pc.bits[*].mc_buf *field_top.mc_buffer_afl_section.bits[*].mc_buf} 1
