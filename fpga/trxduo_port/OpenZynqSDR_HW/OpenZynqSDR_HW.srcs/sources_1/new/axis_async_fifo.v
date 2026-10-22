`timescale 1ns / 1ps
// Async AXIS FIFO (gray-pointer) for clock domain crossing.
// Burst-atomic write side: a burst (wr_en ... wr_last) is only started when at
// least BURST_LEN slots are free; once started it is guaranteed to complete, so
// a TLAST word can NEVER be dropped. If a burst cannot be started it is dropped
// whole (latest-data semantics). This prevents the HLS sender's
// do{read}while(!last) loop from wedging on a lost TLAST.

module axis_async_fifo #(
    parameter WIDTH = 32,
    parameter DEPTH = 64,
    parameter PTRW  = 7,   // log2(DEPTH) + 1
    parameter BURST_LEN = 1 // per-word gating when 1 (back-compat)
)(
    input  wire             wr_clk,
    input  wire             wr_rstn,
    input  wire             wr_en,
    input  wire             wr_last,    // TLAST of the current word
    input  wire [WIDTH-1:0] wr_data,

    input  wire             rd_clk,
    input  wire             rd_rstn,
    input  wire             rd_en,
    output wire             rd_valid,
    output wire [WIDTH-1:0] rd_data,
    output wire             full_o
);
    localparam ADRW = PTRW - 1;
    localparam [PTRW-1:0] DEPTH_V  = DEPTH[PTRW-1:0];
    localparam [PTRW-1:0] BURST_V  = BURST_LEN[PTRW-1:0];

    reg [WIDTH-1:0] ram [0:DEPTH-1];

    reg [PTRW-1:0] wbin, wgray;
    reg [PTRW-1:0] rbin, rgray;
    reg [PTRW-1:0] rgray_w1, rgray_w2;
    reg [PTRW-1:0] wgray_r1, wgray_r2;

    function [PTRW-1:0] bin2gray;
        input [PTRW-1:0] b;
        bin2gray = b ^ (b >> 1);
    endfunction

    function [PTRW-1:0] gray2bin;
        input [PTRW-1:0] g;
        integer i;
        begin
            gray2bin = {PTRW{1'b0}};
            gray2bin[PTRW-1] = g[PTRW-1];
            for (i = PTRW-2; i >= 0; i = i - 1)
                gray2bin[i] = gray2bin[i+1] ^ g[i];
        end
    endfunction

    wire full;
    wire empty = (rgray == wgray_r2);

    // Occupancy in the write domain. DEPTH is a power of two, so modular
    // subtraction of binary pointers gives the true word count (0..DEPTH-1).
    wire [PTRW-1:0] rbin_w = gray2bin(rgray_w2);
    wire [PTRW-1:0] used   = wbin - rbin_w;
    wire [PTRW-1:0] space  = DEPTH_V - used;
    wire can_start = (space >= BURST_V);

    // Burst-in-progress: set while a burst is mid-flight (wr_en high, last not
    // yet seen). Cleared on the word carrying wr_last.
    // burst_drop: the current burst was rejected at its first word (not enough
    // space); keep rejecting until its wr_last so we never write a partial burst.
    reg burst_active;
    reg burst_drop;

    wire start_ok = (BURST_LEN == 1) ? ~full : (can_start & ~burst_drop);
    wire do_write = (BURST_LEN == 1) ? (wr_en & ~full)
                                     : (wr_en & (burst_active | start_ok));

    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) begin
            burst_active <= 1'b0;
            burst_drop   <= 1'b0;
        end else if (BURST_LEN != 1) begin
            if (burst_active) begin
                if (do_write && wr_last) burst_active <= 1'b0;
            end else if (wr_en) begin
                if (start_ok) begin
                    burst_active <= ~wr_last;
                    burst_drop   <= 1'b0;
                end else if (wr_last) begin
                    burst_drop   <= 1'b0;
                end else begin
                    burst_drop   <= 1'b1;
                end
            end
        end else begin
            burst_active <= 1'b0;
            burst_drop   <= 1'b0;
        end
    end

    wire do_read = ~empty & rd_en;

    // RAM write (write clock domain)
    always @(posedge wr_clk) begin
        if (do_write)
            ram[wbin[ADRW-1:0]] <= wr_data;
    end

    // write pointer (wr_clk domain)
    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) begin
            wbin  <= {PTRW{1'b0}};
            wgray <= {PTRW{1'b0}};
        end else if (do_write) begin
            wbin  <= wbin + 1'b1;
            wgray <= bin2gray(wbin + 1'b1);
        end
    end

    // read pointer (rd_clk domain)
    always @(posedge rd_clk or negedge rd_rstn) begin
        if (!rd_rstn) begin
            rbin  <= {PTRW{1'b0}};
            rgray <= {PTRW{1'b0}};
        end else if (do_read) begin
            rbin  <= rbin + 1'b1;
            rgray <= bin2gray(rbin + 1'b1);
        end
    end

    // sync read gray into write domain
    always @(posedge wr_clk or negedge wr_rstn) begin
        if (!wr_rstn) begin
            rgray_w1 <= {PTRW{1'b0}};
            rgray_w2 <= {PTRW{1'b0}};
        end else begin
            rgray_w1 <= rgray;
            rgray_w2 <= rgray_w1;
        end
    end

    // sync write gray into read domain
    always @(posedge rd_clk or negedge rd_rstn) begin
        if (!rd_rstn) begin
            wgray_r1 <= {PTRW{1'b0}};
            wgray_r2 <= {PTRW{1'b0}};
        end else begin
            wgray_r1 <= wgray;
            wgray_r2 <= wgray_r1;
        end
    end

    // full: write gray == read gray with the TOP TWO MSBs inverted and ALL
    // remaining PTRW-2 bits equal. BUG FIX: the old term used
    // rgray_w2[ADRW-1:0] (=PTRW-1:0), which is one bit too wide: the 12-bit
    // RHS never matched the true-full pattern (so the producer overwrote unread
    // words without any backpressure) and instead matched the pattern
    // "empty with rgray[PTRW-1]=1, rgray[PTRW-2]=0" -> full stuck HIGH forever
    // at that pointer position: writes blocked + sender starved inside
    // do{read}while(count<4096) -> permanent wedge (only bit reload recovers).
    // Observed: waterfall ran ~7788 rounds (~0.5s of data) then IRQ51 froze.
    assign full = (wgray == {~rgray_w2[PTRW-1:PTRW-2], rgray_w2[PTRW-3:0]});

    assign rd_valid = ~empty;
    assign rd_data  = ram[rbin[ADRW-1:0]];
    assign full_o   = full;
endmodule
