/*
    Encoder from BCD to Seven-Segment
*/

`ifndef COMPONENTS_SSEGENCODER_V
`define COMPONENTS_SSEGENCODER_V

module ssegencoder(
    output reg  [7:0]       sseg_data,
    /*
        Byte-width wire for seven segment
        output.

        Format:

        A B C D E F G dp
        ^             ^
        |             |
        |             |
       MSB           LSB
    */
    input       [3:0]       hex_data,
    /*
        Nibble-width register for hex data.
        if value is greater than 4'h9, then
        hexadecimal is displayed from A 
        through F
    */
    input                   decimal_point
);

// Data flow, because I can't be arsed.
always@(*)
begin
    case (hex_data)
        4'h0: sseg_data = {7'b1111110, decimal_point};
        4'h1: sseg_data = {7'b0110000, decimal_point};
        4'h2: sseg_data = {7'b1101101, decimal_point};
        4'h3: sseg_data = {7'b1111001, decimal_point};
        4'h4: sseg_data = {7'b0110011, decimal_point};
        4'h5: sseg_data = {7'b1011011, decimal_point};
        4'h6: sseg_data = {7'b1011111, decimal_point};
        4'h7: sseg_data = {7'b1110000, decimal_point};
        4'h8: sseg_data = {7'b1111111, decimal_point};
        4'h9: sseg_data = {7'b1111011, decimal_point};
        4'hA: sseg_data = {7'b1110111, decimal_point};
        4'hB: sseg_data = {7'b0011111, decimal_point};
        4'hC: sseg_data = {7'b1001110, decimal_point};
        4'hD: sseg_data = {7'b0111101, decimal_point};
        4'hE: sseg_data = {7'b1001111, decimal_point}; 
        4'hF: sseg_data = {7'b1000111, decimal_point};
    endcase
end

endmodule

`endif