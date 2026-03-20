`timescale 1ns/1ps
`include "ph_meter_top.v"

/*
 * pH Meter Testbench — single solution per use
 *
 * Simulates exactly one real-world session on the device:
 *   1. Power on
 *   2. Calibrate with three buffer solutions (pH 6.86, 4.00, 9.18)
 *   3. Measure ONE solution under test
 *   4. Read the 7-segment display result
 *
 * ════════════════════════════════════════════════════════
 *  INTERCHANGEABLE SECTION — change these two lines only
 * ════════════════════════════════════════════════════════
 *
 *   `define SOLUTION_ADC   12'd____
 *   `define SOLUTION_NAME  "____________"
 *
 *  Common solutions and approximate ADC values:
 *
 *   ADC    pH (approx)   Solution
 *   ----   -----------   --------------------
 *   3900      2.27       Lemon juice
 *   3765      2.60       Vinegar
 *   3550      3.14       Orange juice
 *   3200      4.00       Tomato juice / acidic buffer
 *   2900      4.75       Black coffee
 *   2048      6.86       Distilled water / neutral buffer
 *   1600      7.76       Baking soda solution
 *    900      9.18       Basic buffer
 *      0     (basic end, calibrated sensor reaches ~pH 11)
 *   4095     (acidic end, calibrated sensor reaches ~pH 1.78)
 *
 * ════════════════════════════════════════════════════════
 */

`define SOLUTION_ADC   12'd3550
`define SOLUTION_NAME  "Orange juice  "

/* ─────────────────────────────────────────────────────── */

module phtb();

    // ── Signals ────────────────────────────────────────────────────────
    reg        clk, rst_n, pwr_btn, calib_btn;
    reg        pH_input, pH_stable, pH_ready;
    reg [11:0] adc_readout;

    // ── State name (GTKWave readable) ───────────────────────────────────
    reg [79:0] state_name;
    always @(*) begin
        case (UUT.system_brain.current_state)
            4'd0:  state_name = "STNDBY   ";
            4'd1:  state_name = "STABILIZE";
            4'd2:  state_name = "COMPUTE  ";
            4'd3:  state_name = "DISPLAY  ";
            4'd4:  state_name = "CAL7     ";
            4'd5:  state_name = "STORE7   ";
            4'd6:  state_name = "CAL4     ";
            4'd7:  state_name = "STORE4   ";
            4'd8:  state_name = "CAL9     ";
            4'd9:  state_name = "STORE9   ";
            default: state_name = "UNKNOWN  ";
        endcase
    end

    // ── 7-segment wires ────────────────────────────────────────────────
    wire [7:0] dispA = UUT.system_datapath.display.dispA;
    wire [7:0] dispB = UUT.system_datapath.display.dispB;
    wire [7:0] dispC = UUT.system_datapath.display.dispC;
    wire [7:0] dispD = UUT.system_datapath.display.dispD;

    // Decoded digit values (visible in GTKWave as plain numbers)
    reg  [3:0] dec_A, dec_B, dec_C, dec_D;
    reg [15:0] seg_decoded; // nibbles: [15:12]=tens [11:8]=ones [7:4]=tenths [3:0]=hundredths

    function [3:0] seg2dig;
        input [7:0] s;
        case (s[7:1])
            7'b1111110: seg2dig = 0;
            7'b0110000: seg2dig = 1;
            7'b1101101: seg2dig = 2;
            7'b1111001: seg2dig = 3;
            7'b0110011: seg2dig = 4;
            7'b1011011: seg2dig = 5;
            7'b1011111: seg2dig = 6;
            7'b1110000: seg2dig = 7;
            7'b1111111: seg2dig = 8;
            7'b1111011: seg2dig = 9;
            default:    seg2dig = 4'hF;
        endcase
    endfunction

    always @(*) begin
        dec_A = seg2dig(dispA);
        dec_B = seg2dig(dispB);
        dec_C = seg2dig(dispC);
        dec_D = seg2dig(dispD);
        seg_decoded = {dec_A, dec_B, dec_C, dec_D};
    end

    // ── DUT ─────────────────────────────────────────────────────────────
    ph_meter_top #(.CLKS_PER_SEC(10)) UUT (
        .clk       (clk),
        .rst_n     (rst_n),
        .pwr_btn   (pwr_btn),
        .calib_btn (calib_btn),
        .adc_readout(adc_readout),
        .pH_input  (pH_input),
        .pH_stable (pH_stable),
        .pH_ready  (pH_ready)
    );

    always #5 clk = ~clk;

    // ── Helper tasks ────────────────────────────────────────────────────
    task wait_state;
        input [3:0] target;
        input integer max_cycles;
        integer n;
        begin
            n = 0;
            while (UUT.system_brain.current_state !== target && n < max_cycles) begin
                @(posedge clk);
                n = n + 1;
            end
            if (n >= max_cycles)
                $display("  [TIMEOUT] stuck at %s", state_name);
        end
    endtask

    // Calibrate one buffer solution.
    // Per spec page 8: assert calib_btn while in STNDBY → enter CALx.
    // pH_stable fires after allowing accumulator to collect samples.
    task calibrate;
        input [11:0] adc_val;
        input [3:0]  store_state;  // expected STORE state (5=STORE7, 7=STORE4, 9=STORE9)
        input [79:0] label;
        begin
            adc_readout = adc_val;
            @(negedge clk); calib_btn = 1;
            @(posedge clk); #1;
            $display("  %s | state=%s blink=%b ctrl=%b",
                label, state_name,
                UUT.system_brain.blink_en, UUT.internal_ctrl_bus);
            repeat(3) @(posedge clk); #1;           // let accumulator fill
            @(negedge clk); pH_stable = 1;
            @(posedge clk); #1;
            pH_stable = 0;
            calib_btn = 0;
            wait_state(store_state, 10);
            $display("  STORE reached | state=%s", state_name);
            // Read display while STORE is active (shows fixed cal pH per spec pages 8-9)
            repeat(8) @(posedge clk); #1;
            $display("  7-seg: dispA=%h dispB=%h dispC=%h dispD=%h  pH %0d%0d.%0d%0d",
                dispA, dispB, dispC, dispD,
                dec_A, dec_B, dec_C, dec_D);
            wait_state(4'd0, 10);  // back to STNDBY
        end
    endtask

    // ── Main stimulus ────────────────────────────────────────────────────
    initial begin
        $dumpfile("ph_meter_waves.vcd");
        $dumpvars(0, phtb);

        // Initial state
        clk = 0;  rst_n = 1;  pwr_btn = 0;  calib_btn = 0;
        pH_input = 0;  pH_stable = 0;  pH_ready = 0;
        adc_readout = 12'd0;

        // ────────────────────────────────────────────────────────────────
        // STEP 1: POWER ON
        // pwr_btn is a level signal (1 = device on)
        // ────────────────────────────────────────────────────────────────
        $display("================================================");
        $display("  pH METER — %s", `SOLUTION_NAME);
        $display("================================================");
        $display("");
        $display("[STEP 1] Power ON");
        #40 pwr_btn = 1;
        @(posedge clk); #1;
        $display("  state=%s", state_name);

        // ────────────────────────────────────────────────────────────────
        // STEP 2: CALIBRATION  (spec pages 8 and 9)
        //
        // CAL7 (pH 6.86): calib_btn pressed in STNDBY  → CAL7 → STORE7
        // CAL4 (pH 4.00): calib_btn pressed in DISPLAY → CAL4 → STORE4
        // CAL9 (pH 9.18): calib_btn pressed in STNDBY  → CAL9 → STORE9
        //
        // STORE7/STORE4/STORE9 each show the fixed buffer pH on the display
        // for one hold period before returning to STNDBY.
        // ────────────────────────────────────────────────────────────────
        $display("");
        $display("[STEP 2] Calibration");

        // ── CAL7: neutral buffer (pH 6.86, ADC 2048) ────────────────────
        $display("");
        $display("  -- CAL7: neutral pH 6.86 --");
        calibrate(12'd2048, 4'd5, "  CAL7");
        $display("  cal_done=%b  intrcpt=%0d",
            UUT.internal_cal_done,
            UUT.system_datapath.arithmem_unit.intrcpt);

        // ── Dummy normal measurement to reach DISPLAY (needed for CAL4) ──
        // Spec page 9: CAL4 is triggered by calib_btn pressed from DISPLAY.
        $display("");
        $display("  -- brief normal flow to reach DISPLAY for CAL4 --");
        adc_readout = 12'd3200;
        @(negedge clk); pH_input = 1;
        wait_state(4'd1, 5);
        repeat(3) @(posedge clk); #1;
        @(negedge clk); pH_stable = 1;
        @(posedge clk); #1; pH_stable = 0;
        wait_state(4'd2, 5);
        @(negedge clk); pH_ready = 1;
        @(posedge clk); #1; pH_ready = 0;
        wait_state(4'd3, 5);

        // ── CAL4: acidic buffer (pH 4.00, ADC 3200) — from DISPLAY ──────
        $display("");
        $display("  -- CAL4: acidic pH 4.00 --");
        @(negedge clk); calib_btn = 1;
        @(posedge clk); #1;
        calib_btn = 0;  pH_input = 0;
        $display("  CAL4  | state=%s blink=%b ctrl=%b",
            state_name, UUT.system_brain.blink_en, UUT.internal_ctrl_bus);
        repeat(3) @(posedge clk); #1;
        @(negedge clk); pH_stable = 1;
        @(posedge clk); #1; pH_stable = 0;
        wait_state(4'd7, 10);
        $display("  STORE reached | state=%s", state_name);
        repeat(8) @(posedge clk); #1;
        $display("  7-seg: dispA=%h dispB=%h dispC=%h dispD=%h  pH %0d%0d.%0d%0d",
            dispA, dispB, dispC, dispD,
            dec_A, dec_B, dec_C, dec_D);
        wait_state(4'd0, 10);
        $display("  cal_done=%b  acidic_point=%0d",
            UUT.internal_cal_done,
            UUT.system_datapath.arithmem_unit.acidic_point);

        // ── CAL9: basic buffer (pH 9.18, ADC 900) — from STNDBY ─────────
        $display("");
        $display("  -- CAL9: basic pH 9.18 --");
        calibrate(12'd900, 4'd9, "  CAL9");
        $display("  cal_done=%b  basic_point=%0d",
            UUT.internal_cal_done,
            UUT.system_datapath.arithmem_unit.basic_point);
        $display("  sens_a=%0d  sens_b=%0d",
            UUT.system_datapath.arithmem_unit.sens_acidic,
            UUT.system_datapath.arithmem_unit.sens_basic);

        // ────────────────────────────────────────────────────────────────
        // STEP 3: MEASURE  (spec page 7)
        //
        // ════════════════════════════════════════════════
        //  SWAP adc_readout HERE to change the solution:
        //    `define SOLUTION_ADC  12'd____
        //    `define SOLUTION_NAME "____________"
        // ════════════════════════════════════════════════
        //
        // STNDBY → [pH_input=1] → STABILIZE (display blinks)
        //        → [pH_stable=1] → COMPUTE  (display blinks)
        //        → [pH_ready=1]  → DISPLAY  (shows pH reading)
        //        → [pH_input=0]  → STNDBY
        // ────────────────────────────────────────────────────────────────
        $display("");
        $display("[STEP 3] Measure: %s  (ADC = %0d)",
            `SOLUTION_NAME, `SOLUTION_ADC);
        $display("");

        // Dip electrode into solution under test
        adc_readout = `SOLUTION_ADC;
        @(negedge clk); pH_input = 1;

        // STNDBY → STABILIZE
        wait_state(4'd1, 5);
        $display("  [STABILIZE] blink=%b  ctrl_bus=%b",
            UUT.system_brain.blink_en, UUT.internal_ctrl_bus);

        // Wait ~30 s for reading to stabilise, then assert pH_stable
        repeat(3) @(posedge clk); #1;
        @(negedge clk); pH_stable = 1;
        @(posedge clk); #1; pH_stable = 0;

        // STABILIZE → COMPUTE
        wait_state(4'd2, 5);
        $display("  [COMPUTE  ] blink=%b  ctrl_bus=%b",
            UUT.system_brain.blink_en, UUT.internal_ctrl_bus);

        // Assert pH_ready once computation is done
        @(negedge clk); pH_ready = 1;
        @(posedge clk); #1; pH_ready = 0;

        // COMPUTE → DISPLAY
        wait_state(4'd3, 5);
        $display("  [DISPLAY  ] blink=%b  ctrl_bus=%b",
            UUT.system_brain.blink_en, UUT.internal_ctrl_bus);

        // Let all 4 display digits fully refresh via the mux
        repeat(8) @(posedge clk); #1;

        // ────────────────────────────────────────────────────────────────
        // RESULT
        // ────────────────────────────────────────────────────────────────
        $display("");
        $display("================================================");
        $display("  RESULT: %s", `SOLUTION_NAME);
        $display("================================================");
        $display("  pH reading : %0d%0d.%0d%0d",
            dec_A, dec_B, dec_C, dec_D);
        $display("  pH (float) : %0.2f",
            UUT.system_datapath.temporary_result / 100.0);
        $display("");
        $display("  7-Segment registers:");
        $display("    dispA = 8'h%h  (tens)        digit %0d", dispA, dec_A);
        $display("    dispB = 8'h%h  (ones + dp)   digit %0d", dispB, dec_B);
        $display("    dispC = 8'h%h  (tenths)      digit %0d", dispC, dec_C);
        $display("    dispD = 8'h%h  (hundredths)  digit %0d", dispD, dec_D);
        $display("");
        $display("  seg_decoded = 16'h%h", seg_decoded);
        $display("  (GTKWave: read as hex nibbles → pH %0d%0d.%0d%0d)",
            dec_A, dec_B, dec_C, dec_D);
        $display("================================================");

        // Remove electrode → return to STNDBY
        @(negedge clk); pH_input = 0;
        wait_state(4'd0, 5);
        $display("");
        $display("  Electrode removed. Device in STNDBY.");
        $display("  To test a different solution:");
        $display("    `define SOLUTION_ADC   12'd<value>");
        $display("    `define SOLUTION_NAME  \"<name>\"");

        #100 $finish;
    end

endmodule
