`timescale 1ns / 1ps

module spi_tb();

    // Signal Declarations
    logic sysclk   = 0;
    logic rst_n    = 0;
    logic spi_clk  = 0;
    logic spi_cs_n = 1;
    logic spi_mosi = 0;
    logic spi_miso;

    // 12 MHz sysclk generation 
    // Period = 83.33 ns -> Half-period = 41.667 ns
    always #41.667 sysclk = ~sysclk;

    // DUT Instantiation
    audio_mixer dut (
        .sysclk(sysclk),
        .rst_n(rst_n),
        .spi_clk(spi_clk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // ---------------------------------------------------------
    // SPI Driver Task (Assumes SPI Mode 0: CPOL=0, CPHA=0)
    // ---------------------------------------------------------
    task automatic spi_transaction(
        input  logic        rw,
        input  logic [4:0]  channel,
        input  logic [4:0]  param_num,
        input  logic [15:0] write_data,
        output logic [31:0] read_data
    );
        logic [31:0] tx_shift;
        logic [31:0] rx_shift;

        // Assemble the 32-bit packet
        tx_shift[31]    = rw;
        tx_shift[30:26] = 5'b0;      // Unassigned bits padded with 0
        tx_shift[25:21] = channel;   // Corrected index order
        tx_shift[20:16] = param_num;
        tx_shift[15:0]  = write_data;

        // Start transaction (Drive Chip Select Low)
        spi_cs_n = 0;
        #500; // Setup delay before clocking starts (1 MHz SPI assumed)

        for (int i = 0; i < 32; i++) begin
            // Drive MOSI prior to the rising edge
            spi_mosi = tx_shift[31];
            tx_shift = tx_shift << 1;
            #500; // Half SPI clock period

            // Rising edge: DUT and TB sample data
            spi_clk = 1;
            rx_shift = {rx_shift[30:0], spi_miso};
            #500; // Half SPI clock period

            // Falling edge
            spi_clk = 0;
        end

        #500;
        spi_cs_n = 1;         // End transaction
        read_data = rx_shift; // Pass received bits to output
        #1000;                // Inter-transaction gap
    endtask

    // ---------------------------------------------------------
    // Main Verification Sequence
    // ---------------------------------------------------------
    initial begin
        logic [31:0] read_val;
        int errors = 0;

        $display("Starting Audio Mixer SPI Verification...");

        // 0. Reset Sequence
        rst_n = 0;
        #200;
        rst_n = 1;
        #500;

        // 1. WRITE PHASE: Loop through all 32 channels
        $display("--- Phase 1: Writing to all 32 channels ---");
        for (int ch = 0; ch < 32; ch++) begin
            // Writing a unique identifiable payload to Parameter 5 of every channel
            // Payload = 16'hA000 + channel number
            spi_transaction(
                .rw(1'b0), 
                .channel(ch[4:0]), 
                .param_num(5'd5), 
                .write_data(16'hA000 + ch), 
                .read_data(read_val)
            );
        end

        // 2. READ & VERIFY PHASE: Read back and check against expected values
        $display("--- Phase 2: Reading and Verifying all 32 channels ---");
        for (int ch = 0; ch < 32; ch++) begin
            logic [15:0] expected_data = 16'hA000 + ch;

            // Perform read (write_data is driven as 0s during a read)
            spi_transaction(
                .rw(1'b1), 
                .channel(ch[4:0]), 
                .param_num(5'd5), 
                .write_data(16'h0000), 
                .read_data(read_val)
            );

            // Compare the lowest 16 bits of the received data
            if (read_val[15:0] !== expected_data) begin
                $error("Mismatch on Channel %0d! Expected: 0x%0x, Got: 0x%0x", ch, expected_data, read_val[15:0]);
                errors++;
            end else begin
                $display("Channel %0d: PASS (Data: 0x%0x)", ch, read_val[15:0]);
            end
        end

        // 3. Final Report
        $display("---------------------------------------------------");
        if (errors == 0) begin
            $display("SUCCESS: All 32 channels verified with no errors.");
        end else begin
            $display("FAILED: Found %0d errors during verification.", errors);
        end
        $display("---------------------------------------------------");

        $finish;
    end

endmodule