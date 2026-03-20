`ifndef PH_METER_TOP_V
`define PH_METER_TOP_V
`include "phctrlr.v"
`include "phitrfc.v"

/*
    pH Meter Top Module
    Ports match professor's original plus cal_done visibility.
    pH_input, pH_stable, pH_ready are testbench-driven (professor's design).
*/
module ph_meter_top #(
    parameter CLKS_PER_SEC = 10
)(
    input        clk,
    input        rst_n,      // Active-low hardware reset
    input        pwr_btn,    // LEVEL: 0=reset to STNDBY, 1=run
    input        calib_btn,
    input [11:0] adc_readout,
    input        pH_input,   // driven by testbench
    input        pH_stable,  // driven by testbench
    input        pH_ready    // driven by testbench
);
    wire [3:0] internal_ctrl_bus;
    wire [2:0] internal_cal_done;
    wire       internal_blink_en;
    wire [1:0] internal_store_display;
    wire       internal_acc_reset;

    phctrlr #(.CLKS_PER_SEC(CLKS_PER_SEC)) system_brain (
        .ctrl_bus      (internal_ctrl_bus),
        .cal_done      (internal_cal_done),
        .blink_en      (internal_blink_en),
        .store_display (internal_store_display),
        .acc_reset     (internal_acc_reset),
        .rst_n         (rst_n),
        .pwr_btn       (pwr_btn),
        .calib_btn     (calib_btn),
        .pH_input      (pH_input),
        .pH_stable     (pH_stable),
        .pH_ready      (pH_ready),
        .clk           (clk)
    );

    phitrfc system_datapath (
        .adc_readout   (adc_readout),
        .ctrl_bus      (internal_ctrl_bus),
        .cal_done      (internal_cal_done),
        .store_display (internal_store_display),
        .acc_reset     (internal_acc_reset),
        .clk           (clk)
    );
endmodule
`endif
