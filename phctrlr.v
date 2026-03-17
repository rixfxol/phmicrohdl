/*
    pH Sensor Controller, defines what
    should occur, when.
*/

`ifndef PHCTRLR_V
`define PHCTRLR_V

module(
    output  reg     [3:0]   ctrl_bus,
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

    input                   pwr_btn,
        // Power Button, Active HIGH(?)
    input                   calib_btn
        // Calibration Button, Active HIGH(?)

    /*
        NOTE: Could also take as input the adc readout,
        to determine if anything has changed, which
        means that something is being measured.
    */

    /*
        Load Value (LDV) could also mean load a value
        after the adc readout has settled for temporary
        saving, or single-shot measurement, as opposed
        to the current assumption, which is continuous
        measurement. 
    */
)

/*
    ! A clocked circuit for a counter could be used for a timer
    ! to turn the display off, or to wait for the adc to settle.
*/


// Implementation here (likely a state machine)

endmodule

`endif