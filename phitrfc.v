/*
    A pH module interface for the arithmetic, accumulator,
    and display units for communicating with the controller
    and providing methods for testbench control.

    pH Application Specific Module Unit
*/

// External Modules
`include "components/accumulator.v"
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
    input           [4:0]   ctrl_bus,
        /*
            Control sourced from the controller.
            Decided that the controller can trigger
            four specific actions in the interface:

            Compute pH (CPH) - Forces a pH computation,
                after value is loaded.
            Load Value (LDV) - Loads a value from the
                ADC for computation, this is the memory
                cell which is also used for calibration
            Acidic Calibration (CBA) - Computes the
                first-step calibration using an acidic
                input.
            Basic Calibration (CBB) - Computes the
                second-step calibration using a basic
                input.
            Display Value (DSV) - Shows the computed
                value on the quadruple seven-segment
                display. If this is low, then the 
                display is off.

            All signals are active HIGH, and is in the
            following format:

            MSB -> [4    3    2    1    0] <- LSB
                    ^    ^    ^    ^    ^
                    |    |    |    |    |
                    |    |    |    |    |
                   DSV  LDV  CPH  CBA  CBB
        */
    input                   clk,
        /*
            Clock input if needed, remove if unused
        */
);

// Local Declarations


wire            dsv, ldv, cph, cba, cbb;    // Wire as explained in ctrl_bus

// Hard Assignments / Aliases
assign dsv = ctrl_bus[4];
assign ldv = ctrl_bus[3];
assign cph = ctrl_bus[2];
assign cba = ctrl_bus[1];
assign cbb = ctrl_bus[0];



endmodule