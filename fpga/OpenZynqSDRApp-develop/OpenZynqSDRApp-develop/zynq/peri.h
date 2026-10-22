#pragma once

#include <sys/wait.h>

#define GPIO_ANTENNA      (1 << 0)
#define GPIO_ANTENNA0     (1 << 0)
#define GPIO_ANTENNA1     (1 << 1)
#define GPIO_ANTENNA2     (1 << 2)
#define GPIO_ANTENNA3     (1 << 3)
#define GPIO_ANTENNA4     (1 << 4)
#define GPIO_ANTENNA5     (1 << 5)
#define GPIO_ANNENNA_MASK (0x7f)

#define GPIO_DITHER (1 << 6)
#define GPIO_PGA    (1 << 7)
#define GPIO_LED    (1 << 8)

//Width of the acumulator in bits
#define RX_SOUND_DDS_RESOLUTION     32 //bits

//Width of the acumulator in bits - waterfall
#define RX_WF_DDS_RESOLUTION        32 //bits

// "overlapped_sampling" is DISABLED. The software pipelining variant (pre-issue
// the next START from fpga_read_wf) was measured on TRX DUO with 8 browser
// connections: ~50% of rounds timed out ("no data" churn) while the PL was
// still delivering 14+ IRQs/s -- the pre-issued STARTs race the read path.
// Reverted to the plain explicit-START loop; frame pacing now comes from the
// corrected samp_wait sleep (WF CIC input = ADC/7) plus a 5ms guard inside
// fpga_start_waterfall().
#define USE_WF_OVERLAP_SAMPLING     false

#define SOUND_CIC1_DECIM        731
// TRX DUO 移植：PL rx_cic_1 按 122.88MHz 重算抽取 = 731（原厂 40MHz 时为 238）。
// 122.88e6/(731*14)=12007Hz 与实测 SND 流 12003Hz 及 SND_RATE_4CH=12000 一致。
#define SOUND_CIC2_DECIM        14
#define SOUND_DECIM             (SOUND_CIC1_DECIM * SOUND_CIC2_DECIM)


void peri_init();
void peri_free();

void rf_enable_airband(bool enabled);
void rf_attn_set(float attn_dB);

void sd_enable(bool write);

extern u64_t fpga_dna();

extern void fpga_start_rx();
extern void fpga_read_rx(void* buf, uint32_t size);
extern void fpga_rxfreq(int rx_chan, uint64_t i_phase);

extern void fpga_start_pps();
extern uint64_t fpga_read_pps();

extern int fpga_set_antenna(int mask);
extern int fpga_set_pga(bool enabled);
extern int fpga_set_dither(bool enabled);
extern int fpga_set_led(bool enabled);

extern uint32_t fpga_signature();

extern void fpga_setovmask(uint32_t mask);
extern void fpga_setadclvl(uint32_t val);

extern int fpga_reset_wf(int wf_chan, bool cont);
extern int fpga_wf_param(int wf_chan, int decimate, uint64_t i_phase);
extern bool fpga_wf_start_needed(int wf_chan);
extern void fpga_wf_abort(int wf_chan);
extern int fpga_get_wf(int rx_chan);
extern void fpga_free_wf(int wf_chan, int rx_chan);
extern void fpga_read_wf(int wf_chan, void* buf, uint32_t size);
