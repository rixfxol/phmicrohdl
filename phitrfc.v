/*
    pH Module Interface
    Restored to professor's original structure.
    Added: store_display mux for STORE7/4/9 fixed output (spec pages 8-9)
           acc_reset for clean accumulator per measurement
           cal_done passed to arithmetic for piecewise sensitivity
*/

`ifndef PHITRFC_V
`define PHITRFC_V

`include "components/arithmetic.v"
`include "components/qsseg.v"

module phitrfc(
    input  [11:0] adc_readout,
    input  [3:0]  ctrl_bus,
    input  [2:0]  cal_done,
    input  [1:0]  store_display,
    input         acc_reset,
    input         clk
);

reg  [3:0] disp_data_bus;
reg  [1:0] display_selector = 2'b0;

wire dsv, nc_ld, cba, cbb;
assign dsv   = ctrl_bus[3];
assign nc_ld = ctrl_bus[2];
assign cba   = ctrl_bus[1];
assign cbb   = ctrl_bus[0];

wire [11:0] data_bus;
assign data_bus = nc_ld ? adc_readout : 12'bz;

arithmetic arithmem_unit (
    .bus(data_bus), .mode({cba, cbb}),
    .neval_load(nc_ld), .cal_done(cal_done),
    .acc_reset(acc_reset), .clk(clk)
);

qsseg display (
    .bus(disp_data_bus), .selector(display_selector),
    .reset(~dsv), .write_clk(clk)
);

// Capture pH result from arithmetic when in compute mode
reg [23:0] temporary_result;
always @(posedge clk) begin
    if (!nc_ld)
        temporary_result <= data_bus;
end

// Mux: STORE states show fixed calibration pH, otherwise computed pH
reg [23:0] display_value;
always @(*) begin
    case (store_display)
        2'b01:   display_value = 24'd686;  // STORE7: show pH 6.86
        2'b10:   display_value = 24'd400;  // STORE4: show pH 4.00
        2'b11:   display_value = 24'd918;  // STORE9: show pH 9.18
        default: display_value = temporary_result;
    endcase
end

// Double-Dabble BCD on display_value
reg  [27:0] bcd_shift;
integer     i;
reg  [15:0] temporary_bcd;

always @(display_value) begin
    bcd_shift        = 28'b0;
    bcd_shift[10:0]  = display_value[10:0];
    for (i = 0; i < 11; i = i + 1) begin
        if (bcd_shift[14:11] > 4) bcd_shift[14:11] = bcd_shift[14:11] + 3;
        if (bcd_shift[18:15] > 4) bcd_shift[18:15] = bcd_shift[18:15] + 3;
        if (bcd_shift[22:19] > 4) bcd_shift[22:19] = bcd_shift[22:19] + 3;
        if (bcd_shift[26:23] > 4) bcd_shift[26:23] = bcd_shift[26:23] + 3;
        bcd_shift = bcd_shift << 1;
    end
    temporary_bcd[15:12] = bcd_shift[26:23]; // thousands (tens of pH)
    temporary_bcd[11:8]  = bcd_shift[22:19]; // hundreds  (ones of pH)
    temporary_bcd[7:4]   = bcd_shift[18:15]; // tens      (tenths)
    temporary_bcd[3:0]   = bcd_shift[14:11]; // ones      (hundredths)
end

wire [3:0] d_tens, d_ones, d_tenths, d_hundredths;
assign d_tens        = temporary_bcd[15:12];
assign d_ones        = temporary_bcd[11:8];
assign d_tenths      = temporary_bcd[7:4];
assign d_hundredths  = temporary_bcd[3:0];

always @(negedge clk) begin
    display_selector = display_selector + 1;
    case (display_selector)
        2'h0: disp_data_bus = d_hundredths;
        2'h1: disp_data_bus = d_tenths;
        2'h2: disp_data_bus = d_ones;
        2'h3: disp_data_bus = d_tens;
    endcase
end

endmodule
`endif
