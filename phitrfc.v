/*
    A pH module interface for the arithmetic, accumulator,
    and display units for communicating with the controller
    and providing methods for testbench control.

    pH Application Specific Module Unit
*/

`ifndef PHITRFC_V
`define PHITRFC_V

// External Modules
`include "components/arithmetic.v"
`include "components/qsseg.v"

module phitrfc(
    input           [11:0]  adc_readout,
        /*
            12-bit ADC value from test bench,
            or, if possible, at initialization,
            a random variation is added to the
            entire readout to facilitate the
            need for calibration.

            Like, since this does not need to
            be synthesized, a random value
            between 0 and ([2^12] - 1) / 5 is
            added (positive or negative) to all
            readouts, which a calibration test
            would be able to do. 
        */
    input           [3:0]   ctrl_bus,
        /*
            Control sourced from the controller.
            Decided that the controller can trigger
            four specific actions in the interface:

            ~Compute / Load (nC/LD) - A single control
                signal for dictating whether the device
                should load a pH readout to the memory
                register or compute the pH from the 
                readout.

            Acidic Calibration (CBA) - Computes the
                first-step calibration using an acidic
                input.
            Basic Calibration (CBB) - Computes the
                second-step calibration using a basic
                input.

            *   When CBA and CBB are HIGH at the SAME TIME, 
            *       the Calibration Computation is the 
            *       Neutral Calibration, which takes as input
            *       the neutral (pH ~7) calibration input.
            *   When CBA and CBB are LOW at the SAME TIME,
            *       it is not in Calibration Mode, but in
            *       pH Calculation Mode, that can be passed
            *       to the display.
            
            Display Value (DSV) - Shows the computed
                value on the quadruple seven-segment
                display. If this is low, then the 
                display is off.

            All signals are active HIGH, and is in the
            following format:

            MSB -> [3    2    1    0] <- LSB
                    ^    ^    ^    ^
                    |    |    |    |
                    |    |    |    |
                   DSV nC/LD CBA  CBB   
        */
    input                   clk
);

// Local Declarations
reg         [3:0]       disp_data_bus;
reg         [1:0]       display_selector = 2'b0;


wire        [11:0]      data_bus;
wire                    dsv, nc_ld, cba, cbb;    // Wire as explained in ctrl_bus

// Hard Assignments / Aliases
assign dsv = ctrl_bus[3];
assign nc_ld = ctrl_bus[2];
assign cba = ctrl_bus[1];
assign cbb = ctrl_bus[0];

// Modules
arithmetic      arithmem_unit(data_bus, {cba, cbb}, nc_ld);
qsseg           display(disp_data_bus, display_selector, dsv, clk);

// Conversion from 12-bit Value to 0-14 fixed point
reg         [23:0]      temporary_result;
always@(nc_ld, cba, cbb)
begin
    if (!(nc_ld & cba & cbb))
    begin
        // Scale down to 0-14 fixed-point
        temporary_result = data_bus * 1400;
        temporary_result = temporary_result / 4095;
    end
end

// Conversion from fixed-point to bcd;
reg         [15:0]      temporary_bcd;
integer i, j;        // These are simulation-only tooling.
always@(temporary_result)
begin
    // Initialize
    temporary_bcd = 16'h0;                              // initialize with zeros
    temporary_bcd[11:0] = temporary_result[11:0];       // initialize with input vector, 11:0 is the 
                                                        // scaled down after division, this should be
                                                        // fixedpoint ab.cd at this.

    for(i = 0; i <= 7; i = i + 1)                       // iterate on structure depth
    begin
        for(j = 0; j <= (i / 3); j = j + 1)             // iterate on structure width
        begin
            if (temporary_bcd[11 - i + 4 * j -:4] > 4)  // if > 4
            begin
                temporary_bcd[11-i+4*j -:4] = temporary_bcd[11 - i + 4 * j -: 4] + 4'd3; 
                                                        // add 3
            end
        end
    end
end


// Display Connections
wire        [3:0]       d_tens, d_ones, d_tenths, d_hundredths;

assign d_tens = temporary_bcd[15:12];
assign d_ones = temporary_bcd[11:8];
assign d_tenths = temporary_bcd[7:4];
assign d_hundredths = temporary_bcd[3:0];

always@(negedge clk)
begin

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