`timescale 1ns/1ps
module mod_top_tb();

    reg clock;
    reg reset;
    wire sd_mosi;
    wire sd_sclk;
    wire sd_cs;
    wire sd_miso;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, mod_top_tb);
        clock = 1'b0;
        reset = 1'b0;

        #100;
        reset = 1'b1;

        #100;
        reset = 1'b0;

        #300000;
        $finish;
    end

    always #5 clock = ~clock; // 100MHz

    wire clk_spi;
    assign clk_spi = clock;

    // SD 卡
    reg [31:0] sdc_address;
    wire sdc_ready;

    reg sdc_read;
    wire [7:0] sdc_read_data;
    wire sdc_read_valid;

    reg sdc_write;
    reg [7:0] sdc_write_data;
    wire sdc_write_ready;

    reg [39:0] miso_data;
    reg [47:0] mosi_data;
    reg [15:0] bit_counter;
    reg busy;
    reg [7:0] busy_counter;
    reg [7:0] busy_cycles;

    wire [47:0] next_mosi_data;
    wire [6:0] command_index;
    wire [31:0] argument;
    wire [6:0] crc7;
    initial begin
        mosi_data = 48'b0;
        miso_data = 40'b0;
        busy = 1'b0;
        busy_counter = 8'b0;
        bit_counter = 16'b0;
    end
    assign next_mosi_data = {mosi_data, sd_mosi};
    assign command_index = mosi_data[45:40];
    assign argument = mosi_data[39:8];
    assign crc7 = mosi_data[7:1];
    assign sd_miso = miso_data[39];

    always @ (negedge sd_sclk) begin
        if (sd_cs == 1'b0) begin
            miso_data <= {miso_data, 1'b0};
        end
    end

    always @ (posedge sd_sclk) begin
        if (sd_cs == 1'b0) begin
            mosi_data <= next_mosi_data;
            bit_counter <= bit_counter + 16'b1;
            // only on byte boundary, bits[47:46]=01, bits[0]=1
            if (bit_counter[2:0] == 3'b0 && bit_counter >= 6*8 && mosi_data[47] == 1'b0 && mosi_data[46] == 1'b1 && mosi_data[0] == 1'b1 && ~busy) begin
                $display("%d: Command: %x, CMD%d, Argument: %x, CRC7: %x", $time, mosi_data, command_index, argument, crc7);
                busy <= 1'b1;
                busy_counter <= 8'b0;
                mosi_data <= 48'b0;

                if (command_index == 8'b0) begin
                    // CMD0
                    // R1
                    // no errors, in idle state
                    miso_data <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1} << 32;
                    busy_cycles <= 8'd8;
                end else if (command_index == 8'd8) begin
                    // CMD8
                    // R7
                    // no errors, in idle state, command version, reserved, voltage accepted, check pattern
                    miso_data <= {7'b0, 1'b1, 4'b0, 16'b0, 4'b0, mosi_data[15:8]};
                    busy_cycles <= 8'd40;
                end else if (command_index == 8'd55) begin
                    // CMD55
                    // R1
                    // no errors, in idle state
                    miso_data <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1} << 32;
                    busy_cycles <= 8'd8;
                end else if (command_index == 8'd41) begin
                    // ACMD55
                    // R1
                    // no errors, initialized
                    miso_data <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} << 32;
                    busy_cycles <= 8'd8;
                end else if (command_index == 8'd17) begin
                    // CMD17
                    // R1
                    // no errors, initialized, add some data
                    // Start Block Token
                    miso_data <= ({1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} << 32) | (8'b11111110 << 24) | 24'h123456;
                    busy_cycles <= 8'd40;
                end
            end

            if (busy) begin
                busy_counter <= busy_counter + 8'b1;
                if (busy_counter + 1 == busy_cycles) begin
                    busy <= 1'b0;
                    bit_counter <= 16'b1;
                end
            end
        end
    end

    mod_top dut(
        .clk_100m(clock),
        .btn_rst(reset),

        .sd_cs(sd_cs),
        .sd_mosi(sd_mosi),
        .sd_miso(sd_miso),
        .sd_sclk(sd_sclk)
    );

endmodule
