`timescale 1ns / 1ps

// Top-level for TRX DUO (XC7Z020) OpenZynqSDR port
// ADC: 16-bit 122.88MHz, use [15:2] = 14 bits
// Clock: ADC DCO differential (U18/U19), 122.88MHz
// Overflow: P20 (adc_ofl_i)

module top_trxduo
(
    // PS7 DDR
    inout [14:0]DDR_addr,
    inout [2:0]DDR_ba,
    inout DDR_cas_n,
    inout DDR_ck_n,
    inout DDR_ck_p,
    inout DDR_cke,
    inout DDR_cs_n,
    inout [3:0]DDR_dm,
    inout [31:0]DDR_dq,
    inout [3:0]DDR_dqs_n,
    inout [3:0]DDR_dqs_p,
    inout DDR_odt,
    inout DDR_ras_n,
    inout DDR_reset_n,
    inout DDR_we_n,
    // PS7 FIXED_IO
    inout FIXED_IO_ddr_vrn,
    inout FIXED_IO_ddr_vrp,
    inout [53:0]FIXED_IO_mio,
    inout FIXED_IO_ps_clk,
    inout FIXED_IO_ps_porb,
    inout FIXED_IO_ps_srstb,
    // ADC clock (differential, 122.88MHz from ADC DCO)
    input adc_clk_p_i,
    input adc_clk_n_i,
    // ADC data (16-bit, single-ended LVCMOS18)
    input [15:0] adc_dat_a_i,
    // ADC overflow flag
    input adc_ofl_i,
    // LED
    output led_o
);

    // --- ADC differential clock buffer ---
    wire adc_clk_ibuf;
    wire clk_adc;

    IBUFDS #(
        .IOSTANDARD("DIFF_HSTL_I_18"),
        .DIFF_TERM("FALSE")
    ) ibufds_adc_clk (
        .I(adc_clk_p_i),
        .IB(adc_clk_n_i),
        .O(adc_clk_ibuf)
    );

    BUFG bufg_adc (
        .I(adc_clk_ibuf),
        .O(clk_adc)
    );

    // --- ADC data capture (source-synchronous, on clk_adc) ---
    reg [15:0] adc_dat_reg;
    always @(posedge clk_adc) begin
        adc_dat_reg <= adc_dat_a_i;
    end

    // Extract 14 bits [15:2], convert offset-binary negative-slope to two's complement
    // Reference: TRX_DUO_125-16 red_pitaya_analog.v: {d[13], ~d[12:0]}
    wire signed [13:0] adc_data = {adc_dat_reg[15], ~adc_dat_reg[14:2]};

    // Extra register stage for metastability protection
    // ADC data is already registered in adc_dat_reg; this adds one more stage
    // so data is stable for 2 full clk_adc periods before BD samples on FCLK_CLK0
    reg signed [13:0] adc_data_reg;
    always @(posedge clk_adc) begin
        adc_data_reg <= adc_data;
    end

    // --- Instantiate BD wrapper ---
    // Note: BD has no clk_adc port - PL modules run on FCLK_CLK0 (122.88MHz from PS7)
    design_1_wrapper design_1_inst (
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .adc_in(adc_data_reg),
        .adc_ofl(adc_ofl_i),
        .adc_ovr_led_n(led_o),
        .test_out2(),
        .clk_adc(clk_adc)
    );

endmodule
