/*
    Quad Seven-Segment Module for displaying Values
*/

`ifndef COMPONENTS_QSSEG_V
`define COMPONENTS_QSSEG_V

// External Sources
`include "components/ssegencoder.v"

module qsseg(
    input       [3:0]       bus,
    /*
        The data bus to write to the quad seven segment.
    */
    input       [1:0]       selector, 
    /*
        Selector logic for which seven segment display to
        write to. 2'b0 means the least significant digit, 
        while 2'b11 means the most significant digit.
    */
    input                   reset,
    /*
        Synchronous signal to reset all seven-segment displays,
        has priority over the bus when writing.
    */
    input                   write_clk
    /*
        Signal that determines when a load happens which
        triggers on the rising edge.
    */
);

// Registers containing Each Seven-Segment Data,
// dispA is Most Significant Digit while dispD is
// Least Significant Digit
reg     [7:0]   dispA, dispB, dispC, dispD;
reg             d_point;

// Intermediate Wire
wire    [7:0]   sseg_bus;

// Decoder to Seven Segment
ssegencoder     decoder(sseg_bus, bus, d_point);

// Monitoring Block for Simulation Only
initial
begin
    $monitor(
        "7SDs: A(h: %h, b: %b) B(h: %h, b: %b) C(h: %h, b: %b) D(h: %h, b: %b)", 
        dispA, dispA,
        dispB, dispB,
        dispC, dispC,
        dispD, dispD 
    );
end

// Processing Signal
always@(posedge write_clk)
begin
    if (reset)
    begin   // Reset to 0 (In 7 Segment Code)
        dispA = 8'b1111110;
        dispB = 8'b1111110;
        dispC = 8'b1111110;
        dispD = 8'b1111110;
    end
    else
    begin   // Write
        case (selector)
            2'h0: 
            begin
                d_point = 1'b0; 
                dispD = sseg_bus;
            end
            2'h1: 
            begin
                d_point = 1'b0;
                dispC = sseg_bus;
            end
            2'h2: 
            begin
                d_point = 1'b1;
                dispB = sseg_bus;
            end
            2'h3: 
            begin
                d_point = 1'b0;
                dispA = sseg_bus;
            end
        endcase
    end
end

endmodule

`endif