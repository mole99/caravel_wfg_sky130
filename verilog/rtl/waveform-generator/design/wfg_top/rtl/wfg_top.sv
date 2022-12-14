// SPDX-FileCopyrightText: © 2022 semify <office@semify-eda.com>
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`ifndef WFG_INTERCONNECT_PKG
`define WFG_INTERCONNECT_PKG
typedef struct packed {
    logic wfg_axis_tvalid;
    logic [31:0] wfg_axis_tdata;
} axis_t;
`endif

module wfg_top #(
    parameter int BUSW = 32
) (
`ifdef USE_POWER_PINS
    inout vccd1,       // User area 1 1.8V supply
    inout vssd1,       // User area 1 digital ground
`endif
    // Wishbone interface signals
    input               io_wbs_clk,
    input               io_wbs_rst,
    input  [(BUSW-1):0] io_wbs_adr,
    input  [(BUSW-1):0] io_wbs_datwr,
    output [(BUSW-1):0] io_wbs_datrd,
    input               io_wbs_we,
    input               io_wbs_stb,
    output              io_wbs_ack,
    input               io_wbs_cyc,

    output wfg_drive_spi_sclk_o,
    output wfg_drive_spi_cs_no,
    output wfg_drive_spi_sdo_o,

    output [31:0] wfg_drive_pat_dout_o,

    // Memory interface
    output        csb1,
    output [ 9:0] addr1,
    input  [31:0] dout1,
    
    output [10:0] io_oeb
);
    assign io_oeb = '0;

    // Wishbone interconnect

    // Adress select lines
    logic wfg_sel;
    logic wfg_core_sel;
    logic wfg_subcore_sel;
    logic wfg_intercnct_sel;
    logic wfg_stim_sine_sel;
    logic wfg_stim_mem_sel;
    logic wfg_drive_spi_sel;
    logic wfg_drive_pat_sel;

    assign wfg_sel           = (io_wbs_adr[BUSW-1:BUSW-4] == 4'h3);  // Base address: 0x30000000

    // Nothing should be assigned to the null page
    assign wfg_core_sel      = (io_wbs_adr[BUSW-5:4] == 28'h01);  // 0x10
    assign wfg_subcore_sel   = (io_wbs_adr[BUSW-5:4] == 28'h02);  // 0x20
    assign wfg_intercnct_sel = (io_wbs_adr[BUSW-5:4] == 28'h03);  // 0x30
    assign wfg_stim_sine_sel = (io_wbs_adr[BUSW-5:4] == 28'h04);  // 0x40
    assign wfg_stim_mem_sel  = (io_wbs_adr[BUSW-5:4] == 28'h05);  // 0x50
    assign wfg_drive_spi_sel = (io_wbs_adr[BUSW-5:4] == 28'h06);  // 0x60
    assign wfg_drive_pat_sel = (io_wbs_adr[BUSW-5:4] == 28'h07);  // 0x70

    // Acknowledgement
    logic wfg_core_ack;
    logic wfg_subcore_ack;
    logic wfg_intercnct_ack;
    logic wfg_stim_sine_ack;
    logic wfg_stim_mem_ack;
    logic wfg_drive_spi_ack;
    logic wfg_drive_pat_ack;

    assign io_wbs_ack = (wfg_core_ack) || (wfg_subcore_ack) || (wfg_intercnct_ack) || (wfg_stim_sine_ack) || (wfg_stim_mem_ack) || (wfg_drive_spi_ack) || (wfg_drive_pat_ack);

    // Return data
    logic [(BUSW-1):0] wfg_core_data;
    logic [(BUSW-1):0] wfg_subcore_data;
    logic [(BUSW-1):0] wfg_intercnct_data;
    logic [(BUSW-1):0] wfg_stim_sine_data;
    logic [(BUSW-1):0] wfg_stim_mem_data;
    logic [(BUSW-1):0] wfg_drive_spi_data;
    logic [(BUSW-1):0] wfg_drive_pat_data;

    logic [(BUSW-1):0] my_io_wbs_datrd;

    always_comb begin
        unique case (1'b1)
            wfg_core_sel:
                my_io_wbs_datrd = wfg_core_data;
            wfg_subcore_sel:
                my_io_wbs_datrd = wfg_subcore_data;
            wfg_intercnct_sel:
                my_io_wbs_datrd = wfg_intercnct_data;
            wfg_stim_sine_sel:
                my_io_wbs_datrd = wfg_stim_sine_data;
            wfg_stim_mem_sel:
                my_io_wbs_datrd = wfg_stim_mem_data;
            wfg_drive_spi_sel:
                my_io_wbs_datrd = wfg_drive_spi_data;
            wfg_drive_pat_sel:
                my_io_wbs_datrd = wfg_drive_pat_data;
            default:
                my_io_wbs_datrd = 'x;
        endcase
    end

    assign io_wbs_datrd = my_io_wbs_datrd;

    // Core synchronisation interface
    logic wfg_core_sync;
    logic wfg_core_subcycle;
    logic wfg_core_start;
    logic [7:0] wfg_core_subcycle_cnt;
    logic wfg_core_active;

    wfg_core_top wfg_core_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_core_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_core_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_core_ack),
        .wbs_dat_o(wfg_core_data),

        .wfg_core_sync_o        (wfg_core_sync),
        .wfg_core_subcycle_o    (wfg_core_subcycle),
        .wfg_core_start_o       (wfg_core_start),
        .wfg_core_subcycle_cnt_o(wfg_core_subcycle_cnt),
        .active_o               (wfg_core_active)
    );

    // Subcore synchronisation interface
    logic wfg_subcore_sync;
    logic wfg_subcore_subcycle;
    logic wfg_subcore_start;
    logic [7:0] wfg_subcore_subcycle_cnt;
    logic wfg_subcore_active;

    wfg_subcore_top wfg_subcore_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_subcore_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_subcore_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_subcore_ack),
        .wbs_dat_o(wfg_subcore_data),

        .wfg_subcore_sync_o        (wfg_subcore_sync),
        .wfg_subcore_subcycle_o    (wfg_subcore_subcycle),
        .wfg_subcore_start_o       (wfg_subcore_start),
        .wfg_subcore_subcycle_cnt_o(wfg_subcore_subcycle_cnt),
        .active_o                  (wfg_subcore_active)
    );

    axis_t driver_0;
    axis_t driver_1;

    wfg_interconnect_top wfg_interconnect_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_intercnct_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_intercnct_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_intercnct_ack),
        .wbs_dat_o(wfg_intercnct_data),

        .stimulus_0,
        .stimulus_1,

        .wfg_axis_tready_stimulus_0(stimulus_0_wfg_axis_tready),
        .wfg_axis_tready_stimulus_1(stimulus_1_wfg_axis_tready),

        .driver_0,
        .driver_1,

        .wfg_axis_tready_driver_0(driver_0_wfg_axis_tready),
        .wfg_axis_tready_driver_1(driver_1_wfg_axis_tready)
    );
    axis_t stimulus_0;
    axis_t stimulus_1;

    logic stimulus_0_wfg_axis_tready;

    wfg_stim_sine_top wfg_stim_sine_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_stim_sine_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_stim_sine_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_stim_sine_ack),
        .wbs_dat_o(wfg_stim_sine_data),

        .wfg_axis_tready_i(stimulus_0_wfg_axis_tready),
        .wfg_axis_tvalid_o(stimulus_0.wfg_axis_tvalid),
        .wfg_axis_tdata_o (stimulus_0.wfg_axis_tdata)
    );

    logic stimulus_1_wfg_axis_tready;

    wfg_stim_mem_top wfg_stim_mem_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_stim_mem_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_stim_mem_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_stim_mem_ack),
        .wbs_dat_o(wfg_stim_mem_data),

        .wfg_axis_tready_i(stimulus_1_wfg_axis_tready),
        .wfg_axis_tvalid_o(stimulus_1.wfg_axis_tvalid),
        .wfg_axis_tdata_o (stimulus_1.wfg_axis_tdata),

        .csb1 (csb1),
        .addr1(addr1),
        .dout1(dout1)
    );

    logic driver_0_wfg_axis_tready;

    wfg_drive_spi_top wfg_drive_spi_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_drive_spi_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_drive_spi_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_drive_spi_ack),
        .wbs_dat_o(wfg_drive_spi_data),

        .wfg_core_sync_i    (wfg_core_sync),
        .wfg_core_subcycle_i(wfg_core_subcycle),

        .wfg_subcore_sync_i    (wfg_subcore_sync),
        .wfg_subcore_subcycle_i(wfg_subcore_subcycle),

        .wfg_axis_tready_o(driver_0_wfg_axis_tready),
        .wfg_axis_tdata_i (driver_0.wfg_axis_tdata),
        .wfg_axis_tlast_i (1'b0),
        .wfg_axis_tvalid_i(driver_0.wfg_axis_tvalid),

        .wfg_drive_spi_sclk_o(wfg_drive_spi_sclk_o),
        .wfg_drive_spi_cs_no (wfg_drive_spi_cs_no),
        .wfg_drive_spi_sdo_o (wfg_drive_spi_sdo_o)
    );

    logic driver_1_wfg_axis_tready;

    wfg_drive_pat_top #(
        .CHANNELS(32)
    ) wfg_drive_pat_top (
        .wb_clk_i (io_wbs_clk),
        .wb_rst_i (io_wbs_rst),
        .wbs_stb_i(io_wbs_stb && wfg_drive_pat_sel && wfg_sel),
        .wbs_cyc_i(io_wbs_cyc),
        .wbs_we_i (io_wbs_we),
        .wbs_sel_i(4'b1111),
        .wbs_dat_i(io_wbs_datwr),
        .wbs_adr_i(wfg_drive_pat_sel ? io_wbs_adr & 4'hF : 4'h0),
        .wbs_ack_o(wfg_drive_pat_ack),
        .wbs_dat_o(wfg_drive_pat_data),

        .wfg_core_sync_i        (wfg_core_sync),
        .wfg_core_subcycle_cnt_i(wfg_core_subcycle_cnt),

        .wfg_subcore_sync_i        (wfg_subcore_sync),
        .wfg_subcore_subcycle_cnt_i(wfg_subcore_subcycle_cnt),

        .wfg_axis_tready_o(driver_1_wfg_axis_tready),
        .wfg_axis_tdata_i (driver_1.wfg_axis_tdata),
        .wfg_axis_tlast_i (1'b0),
        .wfg_axis_tvalid_i(driver_1.wfg_axis_tvalid),

        .pat_dout_o(wfg_drive_pat_dout_o),
        .pat_dout_en_o(wfg_drive_pat_dout_en_o)
    );

    logic [31:0] wfg_drive_pat_dout_en_o;

endmodule
`default_nettype wire
