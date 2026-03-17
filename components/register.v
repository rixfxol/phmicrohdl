/*
    Register Component for the pH Meter, is simply a 12-bit register
    by default, but parameterized to be usable for all sizes
*/

module register #(
    parameter width = 12        
)
( 
    inout           [width - 1:0]  bus,
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
    `ifndef USE_CLOCK       // Only if Clock is not used
    input                   nhold_enable,
    /*
        Active high signal to enable the register, or if low, simply holds
        the current value and bus becomes high impedance.
    */
    `endif
    `ifdef USE_CLOCK        // This is a clocked register if USE_CLOCK is defined
    input                   clk,
    /*
        Clock Signal
    */
    `endif
);

// Data Container Register
reg     [width - 1:0]  mem_array; 

// High Impedance (Disconnected) if in loading/write mode 
// or module is disabled (if USE_CLOCK is not defined)
// Otherwise, in Read Mode
assign bus = (
    `ifndef USE_CLOCK 
        (nread_write & nhold_enable)
    `endif
    `ifdef USE_CLOCK
        nread_write
    `endif
) ? (width)'bz : mem_array;

// Real Processing Blcck
`ifndef USE_CLOCK 
    always
`endif
`ifdef USE_CLOCK
    always@(posedge clk or negedge nreset)
`endif 
begin
    // Conditional for Accessing the Register Write
    if (nread_write) 
    begin   // Write, (Read is defined in assign bus block above)
        if (nreset) mem_array = bus; // If not Reset
        else mem_array = (width)'b0; // Reset
    end
end

endmodule