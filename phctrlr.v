/*
    pH Sensor Controller, defines what
    should occur, when.
*/

module(
    output  reg     [4:0]   ctrl_bus,
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