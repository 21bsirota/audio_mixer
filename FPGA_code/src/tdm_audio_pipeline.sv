`timescale 1ns / 1ps

module tdm_audio_pipeline(
    input  logic        sysclk,
    input  logic        clk_bclk,  // Added: Need BCLK for the deserializers
    input  logic        rst_n,

    // Hardware Audio Interface
    output logic        fsync_out, // Routes to the physical FSYNC pin on ADCs
    input  logic [7:0]  tdm_rx_lines, // The 8 data lines returning from the 8 ADCs

    // Interface to BRAM (Port B)
    output logic [9:0]  bram_addr,
    input  logic [15:0] bram_data
);

    // --- 1. Master FSYNC Generator ---
    logic [6:0] fsync_cnt;
    logic       internal_fsync;

    always_ff @(posedge clk_bclk or negedge rst_n) begin
        if (!rst_n) begin
            fsync_cnt      <= '0;
            internal_fsync <= 1'b0;
        end else begin
            fsync_cnt <= fsync_cnt + 1; // Naturally wraps at 127
            
            // Pulse high for exactly 1 BCLK cycle
            if (fsync_cnt == 7'd127)
                internal_fsync <= 1'b1;
            else
                internal_fsync <= 1'b0;
        end
    end

    // Route out to physical chips (ensure you use an ODDR at the top-level mixer module!)
    assign fsync_out = internal_fsync; 


    // --- 2. Instantiate the 8 Deserializers ---
    // A 2D packed array to hold all 32 incoming audio channels
    logic [31:0] incoming_audio [0:31];
    logic [7:0]  valid_flags;

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_deserializers
            tdm4_deserializer des (
                .rst_n      (rst_n),
                .clk_bclk   (clk_bclk),
                .fsync      (internal_fsync),
                .tdm_rx     (tdm_rx_lines[i]),
                
                // Map the 4 outputs into our 32-channel array
                .ch0_data   (incoming_audio[(i*4) + 0]),
                .ch1_data   (incoming_audio[(i*4) + 1]),
                .ch2_data   (incoming_audio[(i*4) + 2]),
                .ch3_data   (incoming_audio[(i*4) + 3]),
                
                .data_valid (valid_flags[i])
            );
        end
    endgenerate

    // --- 3. DSP Engine Trigger ---
    // Because all deserializers share the same clocks, their valid flags 
    // will pulse at the exact same time. We only need to listen to one.
    logic dsp_start_pulse;
    assign dsp_start_pulse = valid_flags[0];

    // DSP Math Logic will go here.
    // It will wait for dsp_start_pulse, then iterate through incoming_audio[0:31]

endmodule