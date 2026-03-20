`ifndef PHCTRLR_V
`define PHCTRLR_V

/*
    pH Meter Controller FSM
    
    Follows professor's original structure exactly, with additions
    required by PDF pages 7, 8, and 9 only.

    PORT INTERFACE (matches professor's original):
        ctrl_bus   [3:0] out  — [DSV, nC/LD, CBA, CBB]
        cal_done   [2:0] out  — which cal points are stored
        blink_en         out  — HIGH when display should blink (pages 7-9)
        store_display[1:0] out — 01=show 6.86, 10=show 4.00, 11=show 9.18
        pwr_btn          in   — LEVEL: 0=reset to STNDBY, 1=run
        calib_btn        in   — LEVEL: 1=calibrate
        pH_input         in   — driven by testbench
        pH_stable        in   — driven by testbench
        pH_ready         in   — driven by testbench
        clk              in

    STATE MACHINE (professor's states + STORE7/4/9 for spec pages 8-9):
        STNDBY    000
        STABILIZE 001
        COMPUTE   010
        DISPLAY   011
        CAL7      100
        STORE7    101  (new: spec page 8 says STORE7 output = Display pH 6.86)
        CAL4      110  (was 101 in prof's, shifted to make room for STORE7)
        STORE4    111  (new: spec page 9)
        CAL9      1000 (4-bit needed)
        STORE9    1001

    TRANSITIONS (professor's logic preserved, STORE states added):
        STNDBY:    calib_btn -> CAL7   | pH_input -> STABILIZE
        STABILIZE: pH_stable -> COMPUTE
        COMPUTE:   pH_ready  -> DISPLAY
        DISPLAY:   !pH_input -> STNDBY | calib_btn -> CAL4    [prof: same]
        CAL7:      pH_stable -> STORE7                        [prof had: -> STNDBY]
        STORE7:    (1 cycle)  -> STNDBY
        CAL4:      pH_stable -> STORE4
        STORE4:    (1 cycle)  -> STNDBY
        CAL9:      pH_stable -> STORE9
        STORE9:    (1 cycle)  -> STNDBY

    OUTPUTS per PDF pages 7-9:
        STNDBY:    DSV=0 (display off/blank)
        STABILIZE: DSV blinks (page 7: "Blink display _ _ _ _")
        COMPUTE:   DSV blinks (page 7: "Blink display _ _ _ _")
        DISPLAY:   DSV=1, show pH level
        CAL7:      DSV blinks, show "7"   (page 8: "Blink display 7")
        STORE7:    DSV=1, show pH 6.86   (page 8: "Display pH 6.86")
        CAL4:      DSV blinks, show "4"   (page 9)
        STORE4:    DSV=1, show pH 4.00
        CAL9:      DSV blinks, show "9"
        STORE9:    DSV=1, show pH 9.18
*/

module phctrlr #(
    parameter CLKS_PER_SEC = 10
)(
    output reg [3:0] ctrl_bus,
    output reg [2:0] cal_done,
    output reg       blink_en,
    output reg [1:0] store_display, // 00=normal 01=pH6.86 10=pH4.00 11=pH9.18
    output reg       acc_reset,
    input            rst_n,         // Active-low hardware reset (clears cal_done)
    input            pwr_btn,       // LEVEL: 0=reset to STNDBY, 1=run
    input            calib_btn,
    input            pH_input,
    input            pH_stable,
    input            pH_ready,
    input            clk
);

    // Blink counter (0.5 Hz)
    localparam BLINK_HALF    = CLKS_PER_SEC / 2;
    // Display hold: STORE states stay long enough for 4 digits to fully update
    localparam DISPLAY_HOLD  = CLKS_PER_SEC;     // 1 sim-second hold in STORE states
    reg [$clog2(BLINK_HALF+1)-1:0] blink_cnt;
    reg blink_tick;

    // State encoding — 4-bit to accommodate 10 states
    parameter [3:0] STNDBY    = 4'd0,
                    STABILIZE = 4'd1,
                    COMPUTE   = 4'd2,
                    DISPLAY   = 4'd3,
                    CAL7      = 4'd4,
                    STORE7    = 4'd5,
                    CAL4      = 4'd6,
                    STORE4    = 4'd7,
                    CAL9      = 4'd8,
                    STORE9    = 4'd9;

    reg [3:0] current_state, next_state;
    reg [$clog2(DISPLAY_HOLD+1)-1:0] disp_hold_cnt;
    reg disp_hold_done;

    // Sequential — professor's reset style + rst_n for hardware reset
    always @(posedge clk or negedge pwr_btn or negedge rst_n) begin
        if (!rst_n) begin
            current_state  <= STNDBY;
            blink_cnt      <= 0;
            blink_tick     <= 1;
            acc_reset      <= 0;
            disp_hold_cnt  <= 0;
            disp_hold_done <= 0;
            cal_done       <= 3'b000; // rst_n is the only thing that clears cal_done
        end
        else if (!pwr_btn) begin
            current_state <= STNDBY;
            blink_cnt     <= 0;
            blink_tick    <= 1;
            acc_reset     <= 0;
            disp_hold_cnt <= 0;
            disp_hold_done<= 0;
            // cal_done intentionally NOT cleared: calibration persists
        end
        else begin
            // Blink counter
            if (blink_cnt < BLINK_HALF)
                blink_cnt <= blink_cnt + 1;
            else begin
                blink_cnt  <= 0;
                blink_tick <= ~blink_tick;
            end

            // acc_reset: pulse on entering STABILIZE or any CAL state
            acc_reset <= 0;
            if ((next_state == STABILIZE && current_state != STABILIZE) ||
                (next_state == CAL7 && current_state != CAL7) ||
                (next_state == CAL4 && current_state != CAL4) ||
                (next_state == CAL9 && current_state != CAL9))
                acc_reset <= 1;

            // display_hold: count cycles in STORE states before returning
            disp_hold_done <= 0;
            if (current_state == STORE7 || current_state == STORE4 || current_state == STORE9) begin
                if (disp_hold_cnt < DISPLAY_HOLD) disp_hold_cnt <= disp_hold_cnt + 1;
                else begin disp_hold_done <= 1; disp_hold_cnt <= 0; end
            end else
                disp_hold_cnt <= 0;

            current_state <= next_state;

            // Update cal_done on STORE exit
            if (current_state == STORE7) cal_done[0] <= 1;
            if (current_state == STORE4) cal_done[1] <= 1;
            if (current_state == STORE9) cal_done[2] <= 1;
        end
    end

    // Next-state — professor's logic, STORE states added for spec pages 8-9
    always @(*) begin
        next_state = current_state;
        case (current_state)
            STNDBY: begin
                // Route calib_btn to correct CAL state based on what's done
                if (calib_btn && cal_done[1]) next_state = CAL9;
                else if (calib_btn && cal_done[0]) next_state = CAL4;
                else if (calib_btn) next_state = CAL7;
                else if (pH_input) next_state = STABILIZE;
            end
            STABILIZE: if (pH_stable) next_state = COMPUTE;
            COMPUTE:   if (pH_ready)  next_state = DISPLAY;
            DISPLAY: begin
                if (!pH_input)  next_state = STNDBY;
                else if (calib_btn) next_state = CAL4;
            end
            // CAL states -> STORE for 1 cycle, then STNDBY
            CAL7:   if (pH_stable) next_state = STORE7;
            STORE7: if (disp_hold_done) next_state = STNDBY;
            CAL4:   if (pH_stable) next_state = STORE4;
            STORE4: if (disp_hold_done) next_state = STNDBY;
            CAL9:   if (pH_stable) next_state = STORE9;
            STORE9: if (disp_hold_done) next_state = STNDBY;
            default: next_state = STNDBY;
        endcase
    end

    // blink_en — HIGH whenever spec says "blink"
    always @(*) begin
        blink_en = (current_state == STABILIZE ||
                    current_state == COMPUTE   ||
                    current_state == CAL7      ||
                    current_state == CAL4      ||
                    current_state == CAL9);
    end

    // store_display — which fixed pH to show in STORE states
    always @(*) begin
        case (current_state)
            STORE7:  store_display = 2'b01; // pH 6.86
            STORE4:  store_display = 2'b10; // pH 4.00
            STORE9:  store_display = 2'b11; // pH 9.18
            default: store_display = 2'b00;
        endcase
    end

    // ctrl_bus — professor's output encoding + blink gating
    always @(*) begin
        case (current_state)
            STNDBY:    ctrl_bus = 4'b0000;
            STABILIZE: ctrl_bus = {blink_tick, 3'b100}; // blink DSV, nC/LD=1 (load/accumulate)
            COMPUTE:   ctrl_bus = {blink_tick, 3'b000}; // blink DSV, nC/LD=0 (compute mode)
            DISPLAY:   ctrl_bus = 4'b1000;              // DSV=1, compute mode
            CAL7:      ctrl_bus = {blink_tick, 3'b111}; // blink + neutral cal
            STORE7:    ctrl_bus = 4'b1011;              // DSV=1, compute neutral
            CAL4:      ctrl_bus = {blink_tick, 3'b110}; // blink + acidic cal
            STORE4:    ctrl_bus = 4'b1010;              // DSV=1, compute acidic
            CAL9:      ctrl_bus = {blink_tick, 3'b101}; // blink + basic cal
            STORE9:    ctrl_bus = 4'b1001;              // DSV=1, compute basic
            default:   ctrl_bus = 4'b0000;
        endcase
    end

endmodule
`endif
