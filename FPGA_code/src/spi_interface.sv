`timescale 1ns / 1ps

module spi_interface (
    input  logic        sysclk,
    input  logic        rst_n,

    input  logic        cs_n,
    input  logic        sclk,
    input  logic        mosi,
    output logic        miso,
    output logic        miso_en,

    output logic        bram_we,
    output logic [9:0]  bram_addr,
    output logic [15:0] bram_data_write,
    input  logic [15:0] bram_data_read
);

    logic sclk_sync, cs_n_sync, mosi_sync;

    // CDC
    xpm_cdc_array_single #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .SIM_ASSERT_CHK(1),
        .SRC_INPUT_REG(0),
        .WIDTH(3)
    ) sclkcdc (
        .src_in({sclk, cs_n, mosi}),
        .dest_out({sclk_sync, cs_n_sync, mosi_sync}),
        .src_clk(sysclk),
        .dest_clk(sysclk)
    );

    logic sclk_prev, cs_n_prev;
    logic sclk_rising, sclk_falling, cs_n_rising, cs_n_falling;

    always_ff @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_prev <= '0;
            cs_n_prev <= '0;
        end else begin
            sclk_prev <= sclk_sync;
            cs_n_prev <= cs_n_sync;
        end
    end

    assign sclk_rising  = (sclk_sync == 1'b1)  && (sclk_prev == 1'b0);
    assign sclk_falling = (sclk_sync == 1'b0)  && (sclk_prev == 1'b1);
    assign cs_n_rising  = (cs_n_sync == 1'b1)  && (cs_n_prev == 1'b0);
    assign cs_n_falling = (cs_n_sync == 1'b0)  && (cs_n_prev == 1'b1);

    logic [31:0] shift_reg;
    logic [4:0]  bit_cnt; 
    logic        is_read;
    logic [9:0]  latched_addr; // NEW: Dedicated address holding register

    always_ff @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg    <= '0;
            bit_cnt      <= 5'd31;
            is_read      <= 1'b0;
            latched_addr <= '0;
        end else if (cs_n_falling) begin
            bit_cnt      <= 5'd31; 
        end else if (!cs_n_sync && sclk_rising) begin
            shift_reg <= {shift_reg[30:0], mosi_sync};
            bit_cnt   <= bit_cnt - 1;
            
            // Capture the Read/Write flag on the very first bit
            if (bit_cnt == 5'd31) begin
                is_read <= mosi_sync;
            end

            // Capture the Address exactly when it is fully shifted in
            // At bit_cnt == 16, shift_reg[8:0] holds the upper 9 bits of the addr,
            // and mosi_sync holds the final bit.
            if (bit_cnt == 5'd16) begin
                latched_addr <= {shift_reg[8:0], mosi_sync};
            end
        end
    end

    // Use the frozen address for both BRAM reads and final BRAM writes
    assign bram_addr = latched_addr;
    
    // The data is still safely grabbed from the lower 16 at the end of the transaction
    assign bram_data_write = shift_reg[15:0];
    
    // Only write if CS just went high AND we didn't flag this as a read
    assign bram_we = cs_n_rising && !is_read;

    // MISO Output Logic (The "Read" Phase)
    always_ff @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            miso <= 1'b0;
        end else if (!cs_n_sync && sclk_falling && is_read) begin
            if (bit_cnt <= 15) begin
                miso <= bram_data_read[bit_cnt[3:0]];
            end
        end
    end

    assign miso_en = (!cs_n_sync && is_read);
    
endmodule