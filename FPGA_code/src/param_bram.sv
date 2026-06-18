`timescale 1ns / 1ps

module param_bram (
    input  logic        sysclk,
    
    // Port A: SPI Read/Write Interface
    input  logic        we_a,
    input  logic [9:0]  addr_a,
    input  logic [15:0] data_in_a,
    output logic [15:0] data_out_a, // NEW: Data returning to SPI
    
    // Port B: TDM Audio Pipeline (Read-Only)
    input  logic [9:0]  addr_b,
    output logic [15:0] data_out_b
);

    (* ram_style = "block" *) logic [15:0] memory [0:1023];

    // Port A Logic (Write First mode)
    always_ff @(posedge sysclk) begin
        if (we_a) begin
            memory[addr_a] <= data_in_a;
        end
        // Always read out the data at the current address
        data_out_a <= memory[addr_a];
    end

    // Port B Logic
    always_ff @(posedge sysclk) begin
        data_out_b <= memory[addr_b];
    end

endmodule