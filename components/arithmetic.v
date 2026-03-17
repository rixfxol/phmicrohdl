/*
    Arithmetic component that Calculates the pH or
    Slope of the pH using 3-point calibration.
*/

`ifndef COMPONENTS_ARITHMETIC_V
`define COMPONENTS_ARITHMETIC_V

module arithmetic(
    inout       [11:0]      bus,
    /*
        The data bus where the processed values are sourced.
        This becomes an input when neval_load is HIGH, and
        an output when neval_load is low.
    */
    input       [1:0]       mode,
    /*
        The operation mode, where it follows the CBA-CBB
        wire format:

        2'h0: pH Compute
        2'h1: Basic Calibration
        2'h2: Acidic Calibration
        2'h3: Neutral Calibration
    */
    input                   neval_load
    /*
        Signal to set whether the arithmetic unit is loading
        a value or calculating a value.
    */
);

// Wire to route the result values
reg         [11:0]      ph_calibrated;
wire        [11:0]      result;
assign result = ph_calibrated;

// Reading Configuration
assign bus = neval_load ? 12'bz : result;
/*

*/

// Memory Locations
reg         [11:0]      ph_cache, basic_point, neutral_point, acidic_point;
/*
    pH Cache is storage location for the input of a pH Calculation

    Basic Point is the value from the ADC at the calibrated pH 9.18
    Neutral Point is the value from the ADC at the calibrated pH 6.86
    Acidic Point is the value from the ADC at the calibrated pH 4.00
*/

// Intermediate Connections
reg         [23:0]      intermediate;

// Calculated Slope Rises, where the Run is the Sensitivity (12-bit: 4095)
reg         [11:0]      neutral_basic_rise, acidic_neutral_rise;

// Local Parameters
localparam sensitivity = 4095;

// Data Processing
always@(*)
begin
    if (neval_load) 
    begin // On HIGH, load to caches
        // Put to the proper storage location
        case (mode)
        2'h0: ph_cache = bus;           
        2'h1: basic_point = bus;
        2'h2: acidic_point = bus;
        2'h3: neutral_point = bus;
        endcase
    end
    else
    begin // ON LOW, calculate 
        case (mode) 
        2'h0:   // Compute pH
        begin
            /*
                This sequence just maps the readout value of the ADC
                to the 
            */
            if (ph_cache >= neutral_point)
            begin // If Basic or Neutral
                intermediate = ph_cache * neutral_basic_rise;
            end
            else 
            begin // If Acidic
                intermediate = ph_cache * acidic_neutral_rise;
            end

            /*
                The result obtained here is the mapped value from 
                the ADC to its corrected value from calibration.

                ! This is not the pH value from 0-14, but only
                ! the value represented in binary in the 12-bit
                ! range.
            */
            ph_calibrated = intermediate / sensitivity;
        end
        2'h1:   // Compute Neutral-Basic Rise 
        begin
            neutral_basic_rise = basic_point - neutral_point;
        end
        2'h2:   // Compute Acidic-Neutral Rise
        begin
            acidic_neutral_rise = neutral_point - acidic_point;
        end
        2'h3:   // Compute Both Rises
        begin
            neutral_basic_rise = basic_point - neutral_point;
            acidic_neutral_rise = neutral_point - acidic_point;
        end
        endcase
    end
end
endmodule

`endif