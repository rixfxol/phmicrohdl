/*
    Register Component for the pH Meter, is simply a 12-bit register
    by default, but parameterized to be usable for all sizes
*/

`ifndef COMPONENTS_REGISTER_V
`define COMPONENTS_REGISTER_V

module register #(
    parameter width = 12        
)
( 
    inout   [width - 1:0]   bus,
    /*
        12-bit bus for transferring data in and out of the register.
    */
    input                   nread_write,
    /*
        Signal no denote whether to do a read or write on this register,
        read is active low and load is active high.
    */
    input                   nreset,
    /*
        Asynchronous reset 
    */
    input                   nhold_enable,
    /*
        Active high signal to enable the register, or if low, simply holds
        the current value and bus becomes high impedance.
    */
);

// Data Container Register
reg     [width - 1:0]  mem_array; 

// High Impedance (Disconnected) if in loading/write mode 
// or module is disabled (if USE_CLOCK is not defined)
// Otherwise, in Read Mode
assign bus = (nread_write & nhold_enable) ? (width)'bz : mem_array;

// Real Processing Blcck
always
begin
    // Conditional for Accessing the Register Write
    if (nread_write) 
    begin   // Write, (Read is defined in assign bus block above)
        if (nreset) mem_array = bus; // If not Reset
        else mem_array = (width)'b0; // Reset
    end
end

endmodule

`endif