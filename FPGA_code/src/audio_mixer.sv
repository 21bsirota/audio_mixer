`timescale 1ns / 1ps

module audio_mixer (
    input  logic sysclk, // 12 MHz
    input  logic rst_n,

    // SPI from ESP32 -> FPGA
    input  logic spi_clk,
    input  logic spi_cs_n,
    input  logic spi_mosi,
    output logic spi_miso,

    output logic bclk_external,
    output logic mclk_external
);

    logic internal_miso, miso_enable;

    // SPI to BRAM (Write side)
    logic        spi_bram_we;
    logic [9:0]  spi_bram_addr;
    logic [15:0] spi_bram_data_write, spi_bram_data_read;

    // TDM to BRAM (Read side)
    logic [9:0]  tdm_bram_addr;
    logic [15:0] bram_tdm_data;

    // Internal clock signals
    logic clk_mclk; // 12.288 MHz
    logic clk_bclk; // 6.144 MHz
    logic clk_dsp;  // 92.16 MHz

    spi_interface spi (
        .sysclk          (sysclk),
        .rst_n           (rst_n),

        .cs_n            (spi_cs_n),
        .sclk            (spi_clk),
        .mosi            (spi_mosi),
        .miso            (internal_miso),
        .miso_en         (miso_enable),

        .bram_we         (spi_bram_we),
        .bram_addr       (spi_bram_addr),
        .bram_data_write (spi_bram_data_write),
        .bram_data_read  (spi_bram_data_read)
    );

    param_bram param_memory (
        .sysclk     (sysclk),

        .we_a       (spi_bram_we),
        .addr_a     (spi_bram_addr),
        .data_in_a  (spi_bram_data_write),
        .data_out_a (spi_bram_data_read),

        .addr_b     (tdm_bram_addr),
        .data_out_b (bram_tdm_data)
    );

    tdm_audio_pipeline tdm_dsp (
        .sysclk    (sysclk),
        .rst_n     (rst_n),
        .bram_addr (tdm_bram_addr),
        .bram_data (bram_tdm_data)
    );

    assign spi_miso = (miso_enable) ? internal_miso : 1'bz;

    // Create TDM Clocks
    audio_clock_wizard audio_clocks (
        .resetn(rst_n),
        .clk_in1(sysclk),
        
        .clk_out1(clk_mclk),
        .clk_out2(clk_bclk),
        .clk_out3(clk_dsp)
    );

    ODDR oddr_bclk (
        .Q(bclk_external),
        .C(clk_bclk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(~rst_n),
        .S(1'b0)
    );

    ODDR oddr_mclk (
        .Q(mclk_external),
        .C(clk_mclk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(~rst_n),
        .S(1'b0)
    );


endmodule