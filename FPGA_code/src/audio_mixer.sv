`timescale 1ns / 1ps

module audio_mixer (
    input  logic sysclk, // 12 MHz
    input  logic RST_N,

    input  logic SCK,
    input  logic FPGA_CS,
    input  logic MOSI,
    output logic MISO,

    output logic CLK_STANDBY,
    input  logic OSC_CLK,

    output logic MCLK,
    output logic FSYNC,
    output logic BCLK,

    input  logic TX,
    output logic RX,

    inout  logic I2C0_SCL,
    inout  logic I2C0_SDA,
    inout  logic I2C1_SCL,
    inout  logic I2C1_SDA,

    input  logic SDOUT0,
    input  logic SDOUT1,
    input  logic SDOUT2,
    input  logic SDOUT3,
    input  logic SDOUT4,
    input  logic SDOUT5,
    input  logic SDOUT6,
    input  logic SDOUT7,

    output logic DIN0,
    output logic DIN1,

    output logic A_PWRGATE,
    output logic A_PWRGATE2,

    output logic led[1:0],
    output logic led0_b,
    output logic led0_g,
    output logic led0_r
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
        .rst_n           (RST_N),

        .cs_n            (FPGA_CS),
        .sclk            (SCK),
        .mosi            (MOSI),
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
        .rst_n     (RST_N),
        .bram_addr (tdm_bram_addr),
        .bram_data (bram_tdm_data)
    );

    assign MISO = (miso_enable) ? internal_miso : 1'bz;

    // Create TDM Clocks
    audio_clock_wizard audio_clocks (
        .resetn(RST_N),
        .clk_in1(sysclk),
        
        .clk_out1(clk_mclk),
        .clk_out2(clk_bclk),
        .clk_out3(clk_dsp)
    );

    ODDR oddr_bclk (
        .Q(BCLK),
        .C(clk_bclk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(~RST_N),
        .S(1'b0)
    );

    ODDR oddr_mclk (
        .Q(MCLK),
        .C(clk_mclk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(~RST_N),
        .S(1'b0)
    );


endmodule