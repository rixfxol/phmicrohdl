/*
    Arithmetic component - pH calculation matching PDF spec formula.

    PDF FORMULA (pages 2 and 5):
        pH = (sense - intrcpt) / sensitivity

    Where:
        sense       = averaged ADC reading of the unknown solution (stored in ph_cache)
        intrcpt     = averaged ADC reading at pH 6.86 neutral buffer
        sensitivity = piecewise slope scaled x1000, computed from cal points

    ph_cache separates the sense input from the bus output, preventing
    a combinational loop (bus -> ph_result -> bus).

    Load sequence (neval_load=1):
        mode=0: accumulate unknown sense -> commit to ph_cache
        mode=1: accumulate basic   cal   -> commit to basic_point
        mode=2: accumulate acidic  cal   -> commit to acidic_point
        mode=3: accumulate neutral cal   -> commit to intrcpt

    Compute (neval_load=0, mode=0):
        Reads ph_cache (not bus). Drives bus = ph_result[11:0].
        pH = (ph_cache - intrcpt) / sensitivity  (PDF formula)

    Sensitivity wires (combinational, always current):
        sens_acidic = (acidic_point - intrcpt) * 1000 / (PH_ACIDIC - PH_NEUTRAL)
        sens_basic  = (basic_point  - intrcpt) * 1000 / (PH_BASIC  - PH_NEUTRAL)

    Scale factor 1000 keeps intermediates within 24-bit signed range.
        Max: (4095 - 0) * 1000 = 4,095,000 < 8,388,607.
*/

`ifndef COMPONENTS_ARITHMETIC_V
`define COMPONENTS_ARITHMETIC_V

module arithmetic(
    inout       [11:0]  bus,
    input       [1:0]   mode,
    // 2'h0: sense load / pH compute
    // 2'h1: basic   cal point (pH 9.18)
    // 2'h2: acidic  cal point (pH 4.00)
    // 2'h3: neutral cal point (pH 6.86) = intrcpt
    input               neval_load,
    input       [2:0]   cal_done,
    input               acc_reset, // Pulse from controller on entering STABILIZE/CALx
    input               clk
);

// Fixed pH constants x100
localparam signed [10:0] PH_NEUTRAL    = 11'sd686;
localparam signed [10:0] PH_ACIDIC     = 11'sd400;
localparam signed [10:0] PH_BASIC      = 11'sd918;
localparam signed [10:0] DENOM_ACIDIC  = PH_ACIDIC - PH_NEUTRAL; // -286
localparam signed [10:0] DENOM_BASIC   = PH_BASIC  - PH_NEUTRAL; //  232

// Calibration registers
reg [11:0] ph_cache     = 12'd2048; // sense: averaged ADC of unknown solution
reg [11:0] intrcpt      = 12'd2048; // neutral cal point = intrcpt in PDF formula
reg [11:0] acidic_point = 12'd4095;
reg [11:0] basic_point  = 12'd0;

// Sensitivity wires (combinational, no timing issues)
wire signed [23:0] sens_acidic;
wire signed [23:0] sens_basic;

assign sens_acidic = ($signed({1'b0, acidic_point}) - $signed({1'b0, intrcpt}))
                     * 24'sd1000
                     / $signed({{13{DENOM_ACIDIC[10]}}, DENOM_ACIDIC});

assign sens_basic  = ($signed({1'b0, basic_point})  - $signed({1'b0, intrcpt}))
                     * 24'sd1000
                     / $signed({{13{DENOM_BASIC[10]}},  DENOM_BASIC});

// pH result register (x100, e.g. 686 = pH 6.86)
reg signed [13:0] ph_result = 14'sd0;

// Bus: release during load, drive ph_result during compute
assign bus = neval_load ? 12'bz : ph_result[11:0];

// Running average accumulator
reg [27:0] accumulator     = 28'd0;
reg [15:0] sample_count    = 16'd0;
reg        prev_neval_load = 1'b0;

// Clocked: accumulate samples, commit average on neval_load falling edge
always @(posedge clk) begin
    prev_neval_load <= neval_load;

    // acc_reset: controller pulses this HIGH for 1 cycle when entering
    // STABILIZE or a CAL state. This gives a guaranteed clean start for
    // each new measurement or calibration period.
    if (acc_reset) begin
        accumulator  <= 28'd0;
        sample_count <= 16'd0;
    end
    else if (neval_load) begin
        accumulator  <= accumulator + {16'b0, bus};
        sample_count <= sample_count + 1;
    end

    if (prev_neval_load && !neval_load && sample_count > 0) begin
        case (mode)
            2'h0: ph_cache     <= accumulator / sample_count; // sense
            2'h3: intrcpt      <= accumulator / sample_count; // neutral
            2'h2: acidic_point <= accumulator / sample_count; // acidic
            2'h1: basic_point  <= accumulator / sample_count; // basic
        endcase
        accumulator  <= 28'd0;
        sample_count <= 16'd0;
    end
end

// Combinational compute: pH = (ph_cache - intrcpt) / sensitivity
// Reads ph_cache, NOT bus. No combinational loop.
reg signed [23:0] sense_offset;

always @(*) begin
    if (!neval_load && mode == 2'h0) begin
        if (cal_done == 3'b111) begin
            sense_offset = $signed({1'b0, ph_cache}) - $signed({1'b0, intrcpt});
            if ($signed({1'b0, ph_cache}) >= $signed({1'b0, intrcpt}))
                // Acidic side: ph_cache >= intrcpt (higher ADC = more acidic)
                ph_result = $signed(PH_NEUTRAL)
                          + (sense_offset * 24'sd1000) / sens_acidic;
            else
                // Basic side: ph_cache < intrcpt (lower ADC = more basic)
                ph_result = $signed(PH_NEUTRAL)
                          + (sense_offset * 24'sd1000) / sens_basic;
        end
        else begin
            // Uncalibrated: direct linear mapping (matches PDF scaling table)
            ph_result    = ($signed({12'b0, ph_cache}) * 24'sd1400) / 24'sd4095;
            sense_offset = 24'sd0;
        end
        // Clamp to valid pH range 0.00 to 14.00 (spec requirement)
        // ph_result is pH x100, so 0 = pH 0.00, 1400 = pH 14.00
        if (ph_result < 14'sd0)    ph_result = 14'sd0;
        if (ph_result > 14'sd1400) ph_result = 14'sd1400;
    end
    else begin
        ph_result    = ph_result;
        sense_offset = 24'sd0;
    end
end

endmodule

`endif
