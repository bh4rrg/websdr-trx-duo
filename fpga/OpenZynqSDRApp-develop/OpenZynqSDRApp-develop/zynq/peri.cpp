// This part part of the code is used for for communicating with driver (PL -> PS)
// and simple GPIO operations
// SPI is used for controlling FPGA (PL) modules

#include "types.h"
#include "config.h"
#include "kiwi.h"
#include "misc.h"
#include "peri.h"
#include "coroutines.h"
#include "clk.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

#include <atomic>
#include <mutex>
#include <semaphore.h>

#include "arm_math.h"

#include "ioctl.h"
#include <linux/spi/spidev.h>
#include <gpiod.h>

#define EN_SPI_CMD_PRINTF

#define MAX_WF_CHANNELS         2

// NUmber of implemented channels
#define HW_WF_CHANNELS          2
#define HW_SOUND_CHANNELS       8

#define SPI_CMD_SET_RX_FREQ     1
#define SPI_CMD_SET_WF_FREQ     2
#define SPI_CMD_SET_WF_DECIM    3
#define SPI_CMD_START_WF        4

#define SDRDMA_NAME             "/dev/sdrdma"
#define GPIO_CHIP_NAME          "/dev/gpiochip0"

// ZYNQ MIO lines
#define AMP_LTCH_MIO            28
#define AMP_CLK_MIO             29
#define AMP_DATA_MIO            30

#define LED1_MIO                15

// Values for SDRDMA driver
#define RX_READ_BAD_SIZE	    10
#define RX_READ_NO_DATA		    11
#define RX_READ_OK			    20

// AD8370
#define GPIO_VGA_NUM_LINES      3
#define GPIO_VGA_LTCH_OFFSET    0
#define GPIO_VGA_CLK_OFFSET     1
#define GPIO_VGA_DATA_OFFSET    2


#ifdef EN_SPI_CMD_PRINTF
    #define spi_printf(fmt, ...) \
        printf(fmt, ## __VA_ARGS__)
#else
    #define spi_printf(fmt, ...)
#endif


static bool init;

static uint32_t SPI_SPEED = 5000000;
static uint8_t SPI_BITS = 8;//per word

static int sdrdma_fd;//SDRDMA Driver
static int sdr_spi_fd;//SPI Driver (unused: SPI0-EMIO dead on this board, commands via EMIO GPIO bit-bang)

// EMIO GPIO command bit-bang (SPI0-EMIO PS->PL path is dead on TRX DUO).
// PL spi_receiver is wired to PS GPIO_O[3:5]; EMIO line N = gpiochip0 offset 54+N.
// EMIO0 (offset 54) is kernel-occupied (pps-gpio), so use EMIO3/4/5.
#define CMD_CSN_OFF  57 // EMIO3 -> GPIO_O[3]
#define CMD_SCK_OFF  58 // EMIO4 -> GPIO_O[4]
#define CMD_MOSI_OFF 59 // EMIO5 -> GPIO_O[5]
static struct gpiod_line *cmd_csn = NULL, *cmd_sck = NULL, *cmd_mosi = NULL;

static sem_t wf_sem;
static std::atomic<int> wf_using[4];
static int wf_channels;

// Pipelining: a round is "pending" once START has been issued and its data not
// yet consumed. fpga_read_wf() issues the next START immediately after copying
// the finished round, so the PL fills buffer N+1 while the PS FFTs buffer N
// (period = max(round, FFT) instead of round+FFT).
static bool wf_round_pending[MAX_WF_CHANNELS];

typedef struct
{
    uint64_t freq_code;
    int decim_code;
} waterfall_state_t;

waterfall_state_t wf_buf[MAX_WF_CHANNELS];

/// @brief Used for Amp gain controlling, GPIOD library v1.6.x
struct gpiod_line_bulk amp_gpio_lines;

struct gpiod_line *led_line = NULL;

/// @brief Used for Amp gain controlling
struct gpiod_chip *gpio_chip;

int request_output_lines(const char *chip_path, unsigned int *offsets, unsigned int num_lines);
void gpio_send_vga_gain_code(uint8_t code);
void gpio_send_vga_gain_db(float gain_db);

void fpga_start_waterfall(int wf_chan);
//*****************************************************

void peri_init() {
    if (init)
        return;

    int int_clk;
    if (clk.ext_ADC_clk) {
        int_clk = 0;
    }
    else {
        int_clk = 1;
    }

    // load fpga bitstream
    //int status = blocking_system("cat /media/mmcblk0p1/websdr_%s.bit > /dev/xdevcfg", "hf");

    // SPI0-EMIO PS->PL path is dead on TRX DUO: commands are bit-banged on EMIO GPIO
    // (PL spi_receiver wired to GPIO_O[3:5]). sdr_spi_fd kept unused.
    sdr_spi_fd = -1;

    scall(SDRDMA_NAME, sdrdma_fd = open(SDRDMA_NAME, O_RDWR | O_SYNC));
    if (sdrdma_fd <= 0) {
        sys_panic("Failed to open kernel driver");
    }
    else
    {
        printf("Successfully opened kernel device driver!\n");
    }

    // set airband mode
    rf_enable_airband(kiwi.airband);

    static const char *const chip_path = GPIO_CHIP_NAME;
    static unsigned int line_offsets[GPIO_VGA_NUM_LINES] = { AMP_LTCH_MIO, AMP_CLK_MIO, AMP_DATA_MIO };
    int res = request_output_lines(chip_path, line_offsets, GPIO_VGA_NUM_LINES);
    if (!res) 
    {
		sys_panic("Failed to init Amp GPIO");
	}

    // EMIO GPIO command bit-bang lines (EMIO3/4/5 = chip offsets 57/58/59)
    cmd_csn  = gpiod_chip_get_line(gpio_chip, CMD_CSN_OFF);
    cmd_sck  = gpiod_chip_get_line(gpio_chip, CMD_SCK_OFF);
    cmd_mosi = gpiod_chip_get_line(gpio_chip, CMD_MOSI_OFF);
    if (!cmd_csn || gpiod_line_request_output(cmd_csn, "cmd_csn", 1) < 0 ||
        !cmd_sck || gpiod_line_request_output(cmd_sck, "cmd_sck", 0) < 0 ||
        !cmd_mosi || gpiod_line_request_output(cmd_mosi, "cmd_mosi", 0) < 0) {
        sys_panic("Failed to init EMIO command GPIO lines");
    }
    printf("EMIO command bit-bang lines ready (offsets %d/%d/%d)\n", CMD_CSN_OFF, CMD_SCK_OFF, CMD_MOSI_OFF);

    // set default attn to 0
    rf_attn_set(0);

    wf_channels = (fpga_signature() >> 8) & 0x0f;
    sem_init(&wf_sem, 0, wf_channels);

    init = TRUE;
}

void rf_attn_set(float f) {
    printf("Set AD8370 with %f\n", f);
    gpio_send_vga_gain_db(f);

    return;
}

void rf_enable_airband(bool enabled) {
    return;
}

void peri_free() {
    assert(init);

    gpiod_line_release(led_line);
    gpiod_line_release_bulk(&amp_gpio_lines);
    gpiod_chip_close(gpio_chip);

    close(sdrdma_fd);
    close(sdr_spi_fd);
}

static std::atomic<int> write_enabled(0);
void sd_enable(bool write) {
}

static int last = 100;

// The bit-bang cmd bus is shared by several OS tasks (create_task = real
// pthreads): the WF reader sends START_WF every ~68ms while SND tasks send
// SET_RX_FREQ on tuning. Without a lock the two frames interleave and BOTH
// are corrupted -> SET_RX_FREQ lost ~8% of the time = "page shows new freq
// but audio stays on the old one until the next lucky command". Redundant
// re-sends cannot fix interleaving; only bus atomicity can.
static std::mutex spi_bus_lock;

void spi_transfer(int fd, uint8_t *tx, uint8_t *rx, size_t len)
{
	std::lock_guard<std::mutex> guard(spi_bus_lock);
	// SPI0-EMIO dead on TRX DUO: bit-bang the same SPI frame on EMIO GPIO lines
	// (PL spi_receiver wired to GPIO_O[3:5]). fd<0 selects the bit-bang path.
	if (fd < 0) {
		if (!cmd_csn || !cmd_sck || !cmd_mosi) {
			printf("cmd bit-bang lines not ready\n");
			return;
		}
		// Redundant double-send: gpiod_line_set_value is an ioctl, so real bit
		// timing is dominated by kernel scheduling jitter -> ~8% of 48-bit
		// frames are mis-sampled and spi_receiver silently drops them. That
		// lost every kind of command: START_WF -> lost waterfall round (1s
		// stall), SET_RX_FREQ -> CW/SSB tuning silently stuck on old freq,
		// SET_WF_FREQ -> display offset mismatch. All PL commands are
		// idempotent register writes (sender ignores START while busy), so
		// sending each frame twice makes the drop rate ~0.6%.
		for (int copy = 0; copy < 2; copy++) {
			gpiod_line_set_value(cmd_csn, 0);
			usleep(5);
			for (size_t i = 0; i < len; i++) {
				uint8_t b = tx[i];
				for (int bit = 7; bit >= 0; bit--) {
					gpiod_line_set_value(cmd_mosi, (b >> bit) & 1);
					usleep(2);
					gpiod_line_set_value(cmd_sck, 1);
					usleep(2);
					gpiod_line_set_value(cmd_sck, 0);
					usleep(2);
				}
			}
			gpiod_line_set_value(cmd_csn, 1);
			usleep(50);
		}
		if (rx) memset(rx, 0, len);
		return;
	}

	int ret;
	struct spi_ioc_transfer tr = {
		.tx_buf = (unsigned long)tx,
		.rx_buf = (unsigned long)rx,
		.len = len,
        .speed_hz = SPI_SPEED,
		.delay_usecs = 0,
		.bits_per_word = SPI_BITS,
	};

	ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1)
		printf("can't send spi message");
}
////////////////////////////////
// FPGA DNA
////////////////////////////////

u64_t fpga_dna() {
    int rc;
    uint64_t signature = 0;
    return signature;
}

uint32_t fpga_signature() {
    int rc;
    uint32_t signature = HW_SOUND_CHANNELS + (HW_WF_CHANNELS << 8);
    return signature;
}

/// @brief Called once at startup
void fpga_start_rx() {
    //uint32_t decim = uint32_t(ADC_CLOCK_NOM / 12000 / 256);
    //int rc = ioctl(sdrdma_fd, RX_START, decim);
    //if (rc)
    //    sys_panic("Start RX failed");
}

/// @brief Set sound channel frequency
/// @param rx_chan Starts from 0
/// @param i_phase New value of DDS phase accumulator increment
void fpga_rxfreq(int rx_chan, uint64_t i_phase) {

    uint8_t payload_tx[6];
    uint8_t payload_rx[6];

    payload_tx[0] = SPI_CMD_SET_RX_FREQ;
    payload_tx[1] = (uint8_t)rx_chan;

    payload_tx[2] = (uint8_t)(((uint32_t)i_phase & 0xFF000000) >> 24);
    payload_tx[3] = (uint8_t)(((uint32_t)i_phase & 0x00FF0000) >> 16);
    payload_tx[4] = (uint8_t)(((uint32_t)i_phase & 0x0000FF00) >> 8);
    payload_tx[5] = (uint8_t)(((uint32_t)i_phase & 0x000000FF) >> 0);

    spi_transfer(sdr_spi_fd, payload_tx, payload_rx, sizeof(payload_tx));

    spi_printf("SPI: CMD=%x CH=%x %x %x %x %x\n", payload_tx[0], payload_tx[1], payload_tx[2], payload_tx[3], payload_tx[4], payload_tx[5]);
}

/// @brief Request sound data (for all channels)
/// @param buf - destitation buffer
/// @param size - bytes to copy
void fpga_read_rx(void* buf, uint32_t size) {
    int rc;
    struct rx_read_op read_op = { (__u32)buf, size }; //address, length

    while (true) {
        // printf("In: 0x%x %d\t", read_op.destination, read_op.length);
        rc = ioctl(sdrdma_fd, RX_READ, &read_op);
        if (rc)
            break;

        if (read_op.result != RX_READ_OK)
        {
            TaskSleepMsec(10);
        }
        else {
            break;
        }
    }

    if (rc < 0) {
        lprintf("Read RX failed");
    }
}

void fpga_start_pps() {
    //int rc = ioctl(sdrdma_fd, PPS_START, 1);
    //if (rc)
    //    sys_panic("Start PPS failed");
}

uint64_t fpga_read_pps() {
    uint32_t pps = 0;
    return pps;
}

int fpga_set_antenna(int mask) {
    /*
    uint32_t gpio;
    int rc = ioctl(sdrdma_fd, GET_GPIO_MASK, &gpio);
    if (rc)
        lprintf("Get GPIO failed");

    gpio &= ~GPIO_ANNENNA_MASK;
    gpio |= (mask & GPIO_ANNENNA_MASK);

    rc = ioctl(sdrdma_fd, SET_GPIO_MASK, gpio);
    if (rc)
        lprintf("Set GPIO failed");
    */

    return 0;
}



int fpga_set_pga(bool enabled) {
    return 0;
}

int fpga_set_dither(bool enabled) {
    return 0;
}

int fpga_set_led(bool enabled) {

    int val = enabled ? 0 : 1;//1 -> LED is OFF

    if (led_line)
        gpiod_line_set_value(led_line, val);
    return 0;
}

void fpga_setovmask(uint32_t mask) {
}

void fpga_setadclvl(uint32_t val) {
}

// WATERFALL *********************************************

/// @brief Start WF channel read
/// @param wf_chan 
/// @param cont - continues, set to true when overlapped mode is needed
/// @return 
int fpga_reset_wf(int wf_chan, bool cont) {
    int rc = 0;
    int data = wf_chan;

    if (cont) {
        data |= WF_READ_CONTINUES;
    }

    if (wf_chan >= 0 && wf_chan < MAX_WF_CHANNELS)
        wf_round_pending[wf_chan] = true;

    fpga_start_waterfall(wf_chan);

    return rc;
}

/// @brief Set waterfall channel frequency
/// @param wf_chan channel, starts from 0
/// @param i_phase New value of DDS phase accumulator increment
void fpga_set_wf_freq(int wf_chan, uint64_t i_phase) 
{
    uint8_t payload_tx[6];
    uint8_t payload_rx[6];

    payload_tx[0] = SPI_CMD_SET_WF_FREQ;
    payload_tx[1] = (uint8_t)wf_chan + 1;

    payload_tx[2] = (uint8_t)(((uint32_t)i_phase & 0xFF000000) >> 24);
    payload_tx[3] = (uint8_t)(((uint32_t)i_phase & 0x00FF0000) >> 16);
    payload_tx[4] = (uint8_t)(((uint32_t)i_phase & 0x0000FF00) >> 8);
    payload_tx[5] = (uint8_t)(((uint32_t)i_phase & 0x000000FF) >> 0);

    spi_transfer(sdr_spi_fd, payload_tx, payload_rx, sizeof(payload_tx));

    spi_printf("SPI: CMD=%x CH=%x %x %x %x %x\n", payload_tx[0], payload_tx[1], payload_tx[2], payload_tx[3], payload_tx[4], payload_tx[5]);
}

/// @brief Set waterfall decimation
/// @param wf_chan Channel, starts from 0
/// @param decimation Decimation factor, 1,2,4....
void fpga_set_wf_cic_decim(int wf_chan, int decimation) 
{
    uint8_t payload_tx[6];
    uint8_t payload_rx[6];

    payload_tx[0] = SPI_CMD_SET_WF_DECIM;
    payload_tx[1] = (uint8_t)wf_chan + 1;
    payload_tx[2] = 0;
    payload_tx[3] = 0;
    payload_tx[4] = (uint8_t)(((uint32_t)decimation & 0x0000FF00) >> 8);
    payload_tx[5] = (uint8_t)(((uint32_t)decimation & 0x000000FF) >> 0);

    spi_transfer(sdr_spi_fd, payload_tx, payload_rx, sizeof(payload_tx));

    spi_printf("SPI: CMD=%x CH=%x %x %x %x %x\n", payload_tx[0], payload_tx[1], payload_tx[2], payload_tx[3], payload_tx[4], payload_tx[5]);
}

/// @brief Start waterfall capture
/// @param wf_chan Channel, starts from 0
void fpga_start_waterfall(int wf_chan)
{
    // Guard delay: a START issued within the same few-ms window as round
    // completion is swallowed by the PL sender (done->idle transition misses
    // start_send decoding). 5ms reliably crosses that window; the sender
    // ignores STARTs while busy, so the delay is harmless mid-round.
    TaskSleepMsec(5);
    uint8_t payload_tx[6];
    uint8_t payload_rx[6];
    memset(payload_tx, 0 , 6);
    payload_tx[0] = SPI_CMD_START_WF;
    payload_tx[1] = (wf_chan + 1) & 0x0f;

    // Redundant double-send is handled centrally in spi_transfer() (bit-bang
    // path), which covers every PL command (START_WF / SET_RX_FREQ / SET_WF_*).
    spi_transfer(sdr_spi_fd, payload_tx, payload_rx, sizeof(payload_tx));
}



/// @brief Set both waterfall frequency and decimation
/// @param wf_chan Channel, starts from 0
/// @param decimate Decimation factor, 1,2,4....
/// @param i_phase New value of DDS phase accumulator increment
/// @return 
int fpga_wf_param(int wf_chan, int decimate, uint64_t i_phase) 
{
    int rc = 0;

    if (wf_chan >= MAX_WF_CHANNELS)
        return 0;

    waterfall_state_t *wf_state = &wf_buf[wf_chan];

    if (wf_state->freq_code != i_phase)
    {
        wf_state->freq_code = i_phase;

        float freq = (float)i_phase / (float)pow(2, RX_WF_DDS_RESOLUTION) * (float)122.88f;//mhz
        printf("WF ch=%d changed dec=%d  FREQ=%f\n", wf_chan, decimate, freq);
        fpga_set_wf_freq(wf_chan, i_phase);
    }

    if (wf_state->decim_code != decimate)
    {
        wf_state->decim_code = decimate;
        float freq = (float)(wf_state->freq_code) / (float)pow(2, RX_WF_DDS_RESOLUTION) * (float)122.88f;//mhz
        printf("WF ch=%d changed DEC=%d  freq=%f\n", wf_chan, decimate, freq);
        fpga_set_wf_cic_decim(wf_chan, decimate);
        // Let the PL CIC latch the new decimation before any START. Measured
        // (wfprobe11): an immediate START after SET_WF_DECIM can silently kill
        // the round on some decim values (e.g. 512 -> no data_ready at all).
        TaskSleepMsec(100);
    }

    return rc;
}



void fpga_read_wf(int wf_chan, void* buf, uint32_t size) 
{
    int rc;
    struct wf_read_op read_op = { (__u16)wf_chan, (__u32)buf, (__u32)size };
    int retries = 0;
    int dead_rounds = 0;
    // Self-heal deadline. Worst-case capture round is decim=2048 ->
    // 1024*2048/17.55MHz ~= 120ms, so 300 polls (~300ms) still clears every
    // real round with 2.5x margin. It used to be 1000ms: with the bit-bang
    // command bus, every lost START frame cost a full second of waterfall
    // stall (measured 1-8 big_gaps per 30s), which is what made fps swing
    // 8-13. A spurious early re-START is harmless: the sender ignores STARTs
    // mid-round, and if the round did complete the re-START just queues the
    // next one. (An earlier adaptive deadline keyed on wf_buf[].decim_code
    // was wrong: that field does not reliably track the live decimation.)
    int tmo_retries = 300;
    while (true) {
        // printf("In: 0x%x %d\t", read_op.destination, read_op.length);
        rc = ioctl(sdrdma_fd, WF_READ, &read_op);

        if (rc)
            break;
        // printf("OUT: 0x%x %d -> %d\n", read_op.destination, read_op.length, read_op.result);

        if (read_op.result != RX_READ_OK) 
        {
            TaskSleepMsec(1);
            // Self-heal: if the round-complete IRQ pulse was lost (e.g. swallowed
            // by the PL interrupt stretcher window), the sender sits idle waiting
            // for a START we already sent and this loop would spin forever.
            // After a capture-time-scaled deadline with no data re-issue START.
            // The sender only decodes start_send in its idle state, so a spurious
            // extra START during an in-flight round is ignored; if the round did
            // complete the re-START just produces a fresh frame a few ms later.
            if (++retries >= tmo_retries) {
                retries = 0;
                // NO bitstream reload watchdog here: measured on TRX DUO, a
                // reload every ~2s never restored IRQ51 and instead reset the
                // whole PL (killed sound DDS config, blanked the waterfall
                // every ~1s -> "waterfall stops <2s, black"). Reload = damage.
                // re-START alone is safe (sender ignores it mid-round).
                if (++dead_rounds < 2 || (dead_rounds % 25) == 0)
                    printf("WF ch=%d no data %dms -> re-START x%d\n", wf_chan, tmo_retries, dead_rounds);
                fpga_start_waterfall(wf_chan);
            }
            continue;
        }
        else 
        {
            dead_rounds = 0;
            break;
        }
    }

    if (rc) {
        if (wf_chan >= 0 && wf_chan < MAX_WF_CHANNELS)
            wf_round_pending[wf_chan] = false;
        lprintf("Read WF failed");
        return;
    }

    // Round consumed: PL sender is now idle. Clear pending so the caller can
    // issue the next START (with any updated params) before it runs the FFT,
    // overlapping round N+1 with FFT(N). See sample_wf().
    if (wf_chan >= 0 && wf_chan < MAX_WF_CHANNELS)
        wf_round_pending[wf_chan] = false;

    // Software overlapped sampling / pipelining: pre-issue the next START
    // after a short guard delay. Measured (wfprobe12/13 + websdr "no data x1"
    // alternating pattern): a START issued within the same few-ms window as
    // round completion is swallowed by the PL sender (done->idle transition
    // misses start_send), so the round never starts. 5ms crosses that window
    // reliably (done pulse is us-scale on the 17.55MHz domain).
    if (wf_chan >= 0 && wf_chan < MAX_WF_CHANNELS) {
        TaskSleepMsec(5);
        fpga_start_waterfall(wf_chan);
    }
}

// True when no round is currently pending for this channel, i.e. the caller
// must issue a START before fpga_read_wf() would otherwise block forever.
bool fpga_wf_start_needed(int wf_chan) {
    if (wf_chan < 0 || wf_chan >= MAX_WF_CHANNELS)
        return true;
    return !wf_round_pending[wf_chan];
}

// Clear any pending-round bookkeeping when a WF connection is torn down, so a
// later connection on the same channel does not wait on a START that was never
// issued (the old coroutine is gone and nobody will consume its round).
void fpga_wf_abort(int wf_chan) {
    if (wf_chan >= 0 && wf_chan < MAX_WF_CHANNELS)
        wf_round_pending[wf_chan] = false;
}

int fpga_get_wf(int rx_chan) {
    int ret = -1;

    while (ret) {
        ret = sem_wait(&wf_sem);
    }

    for (int i = 0; i < wf_channels; i++) {
        int empty = 0;
        bool exchanged = wf_using[i].compare_exchange_strong(empty, rx_chan + 10);

        if (exchanged) {
            return i;
        }
    }

    panic("Run out of wf channels");

    return -1;
}

void fpga_free_wf(int wf_chan, int rx_chan) {
    if (rx_chan > 0) {
        rx_chan += 10;

        bool exchanged = wf_using[wf_chan].compare_exchange_strong(rx_chan, 0);
        assert(exchanged);
    }
    else {
        wf_using[wf_chan].store(0);
    }

    int ret = sem_post(&wf_sem);
    if (ret) panic("sem_post failed");
}

// Used for GPIO init
int request_output_lines(const char *chip_path, unsigned int *offsets, unsigned int num_lines)
{
	int ret;
    
	gpio_chip = gpiod_chip_open(chip_path);
	if (!gpio_chip)
		return -1;
    
    ret = gpiod_chip_get_lines(gpio_chip, offsets, GPIO_VGA_NUM_LINES, &amp_gpio_lines);
    if(ret)
    {
        printf("gpiod_chip_get_lines FAIL\n");
        ret = -1;
        goto clear_lines;
    }
    
    ret = gpiod_line_request_bulk_output(&amp_gpio_lines,"amp_gpio", NULL);
    if (ret)
    {
        printf("gpiod_line_request_bulk FAIL\n");
        ret = -1;
        goto clear_lines;
    }

    printf("GPIO Request bulk OK\n");

    led_line = gpiod_chip_get_line(gpio_chip, LED1_MIO);
    if (!led_line) 
    {
        led_line = NULL;
    }

    if (led_line)
    {
        ret = gpiod_line_request_output(led_line, "led1_gpio", 0);
        if (ret < 0)
        {
            printf("Request line as output failed\n");
            led_line = NULL;
        }
    }
    else
    {
        printf("Can't init LED line\n");
    }

    if (led_line)
        gpiod_line_set_value(led_line, 1);//1 -> LED is OFF
    else
        printf("Can't init LED\n");


    return 1;


clear_lines:
    gpiod_line_release_bulk(&amp_gpio_lines);
	gpiod_chip_close(gpio_chip);

	return ret;
}

void gpio_send_vga_gain_db(float gain_db)
{
    if (gain_db < -20)
        gain_db = -20;
    else if (gain_db > 34)
        gain_db = 34;
    //Convert dB to V/V
    float gain_voltage = powf(10.0f, (gain_db / 20.0f));

    float code_lg = gain_voltage / 0.059f;//low gain - value from datasheet
    float code_hg = gain_voltage / 0.409f;//high gain - value from datasheet

    if (code_hg > 127.0f)
        code_hg = 127.0f;


    uint8_t final_code;
    if (gain_db >= 16.5f) //close to low gain maximum
    {
        if (code_hg > 127.0f)
            code_hg = 127.0f;
        final_code = (uint8_t)code_hg;
        final_code |= 0x80;//Use high gain
    }
    else
    {
        if (code_lg > 127.0f)
            code_lg = 127.0f;
        final_code = (uint8_t)code_lg;
    }
    printf("Set AD8370 gain code %d\n", final_code);
    gpio_send_vga_gain_code(final_code);
}

/// @brief Send AD8370 code
/// @param code - AD8370 gain code
void gpio_send_vga_gain_code(uint8_t code)
{
	uint8_t i;
    uint8_t data_bit;
    
    int values[GPIO_VGA_NUM_LINES] = { 0, 0, 0 };//latch, clock, data
    //Bulk operations are slower, but I can't run "gpiod_line_bulk_get_line" well.
    gpiod_line_set_value_bulk(&amp_gpio_lines, values);
    
	for(i = 8; i > 0; i--)
	{
		data_bit = (code & 0x80) != 0;
        
        values[GPIO_VGA_DATA_OFFSET] = data_bit;
        gpiod_line_set_value_bulk(&amp_gpio_lines, values);
        
        values[GPIO_VGA_CLK_OFFSET] = 1;
        gpiod_line_set_value_bulk(&amp_gpio_lines, values);
		code = code << 1;
        values[GPIO_VGA_CLK_OFFSET] = 0;
        gpiod_line_set_value_bulk(&amp_gpio_lines, values);
	}
    values[GPIO_VGA_LTCH_OFFSET] = 1;
    gpiod_line_set_value_bulk(&amp_gpio_lines, values);
    values[GPIO_VGA_DATA_OFFSET] = 0;
    gpiod_line_set_value_bulk(&amp_gpio_lines, values);
}
